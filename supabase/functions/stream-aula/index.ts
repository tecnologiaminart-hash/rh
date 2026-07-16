// Proxy de streaming: recebe ?aula=<id>&token=<token de streaming>, valida o
// token (assinado por get-video-token), busca o ID do arquivo no Drive a
// partir do banco (nunca do cliente) e encaminha os bytes do Google Drive
// pro navegador — incluindo Range Requests (Accept-Ranges/206 Partial
// Content), pra dar play/pause/seek normalmente. O corpo da resposta do
// Drive é repassado como stream (response.body direto), sem nunca carregar
// o vídeo inteiro na memória da function.
//
// Esta função é chamada direto pelo <video src="...">, sem header
// Authorization (o navegador não manda headers custom em tags de mídia) —
// por isso ela roda com verify_jwt DESLIGADO (ver supabase/config.toml) e
// faz sua própria autorização via o token na query string.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { verifyStreamToken } from '../_shared/stream-token.ts';
import { getDriveAccessToken, extrairDriveFileId } from '../_shared/google-drive.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const STREAM_CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'range',
  'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
};

// Cabeçalhos da resposta do Drive que fazem sentido repassar pro navegador
// tal como vieram (tamanho, tipo, faixa de bytes, cache, ETag para range
// requests condicionais).
const PASSTHROUGH_HEADERS = ['Content-Type', 'Content-Length', 'Content-Range', 'ETag', 'Cache-Control'];

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: STREAM_CORS_HEADERS });
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    return new Response('Método não permitido.', { status: 405, headers: STREAM_CORS_HEADERS });
  }

  const url = new URL(req.url);
  const aulaId = url.searchParams.get('aula');
  const token = url.searchParams.get('token');
  if (!aulaId || !token) {
    return new Response('Parâmetros ausentes.', { status: 400, headers: STREAM_CORS_HEADERS });
  }

  const payload = await verifyStreamToken(token);
  if (!payload || String(payload.aid) !== String(aulaId)) {
    return new Response('Token inválido ou expirado.', { status: 401, headers: STREAM_CORS_HEADERS });
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const { data: aula } = await supabase
    .from('curso_aulas')
    .select('url_video, tipo_video')
    .eq('id', aulaId)
    .single();
  if (!aula || aula.tipo_video !== 'upload') {
    return new Response('Vídeo não encontrado.', { status: 404, headers: STREAM_CORS_HEADERS });
  }

  const driveFileId = extrairDriveFileId(aula.url_video);
  if (!driveFileId) {
    return new Response('Vídeo mal configurado.', { status: 500, headers: STREAM_CORS_HEADERS });
  }

  let accessToken: string;
  try {
    accessToken = await getDriveAccessToken();
  } catch (e) {
    console.error('Falha ao autenticar com a Service Account do Google:', e);
    return new Response('Falha ao autenticar com o Google Drive.', { status: 502, headers: STREAM_CORS_HEADERS });
  }

  const driveHeaders = new Headers({ Authorization: `Bearer ${accessToken}` });
  const range = req.headers.get('Range');
  if (range) driveHeaders.set('Range', range);

  const driveResp = await fetch(
    `https://www.googleapis.com/drive/v3/files/${driveFileId}?alt=media&supportsAllDrives=true`,
    { method: req.method, headers: driveHeaders },
  );

  if (!driveResp.ok && driveResp.status !== 206) {
    const body = await driveResp.text().catch(() => '');
    console.error('Drive respondeu erro ao pedir o vídeo:', driveResp.status, body);
    return new Response('Falha ao obter o vídeo do Drive.', { status: 502, headers: STREAM_CORS_HEADERS });
  }

  const respHeaders = new Headers(STREAM_CORS_HEADERS);
  respHeaders.set('Accept-Ranges', 'bytes');
  for (const h of PASSTHROUGH_HEADERS) {
    const v = driveResp.headers.get(h);
    if (v) respHeaders.set(h, v);
  }
  if (!respHeaders.has('Content-Type')) respHeaders.set('Content-Type', 'video/mp4');

  return new Response(req.method === 'HEAD' ? null : driveResp.body, {
    status: driveResp.status,
    headers: respHeaders,
  });
});
