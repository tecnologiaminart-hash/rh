// Recebe o ID de uma aula (curso_aulas.id), confere se o usuário logado tem
// direito de assistir esse curso (mesma regra de acesso da tela "Meus
// Cursos": Administrador/RH sempre podem, os demais precisam de uma linha
// "Liberado" em curso_liberacoes) e devolve um token de streaming de curta
// duração — NUNCA o ID do arquivo no Drive, que fica só no servidor.
//
// Chamada normal, via fetch() com Authorization: Bearer <access_token da
// sessão>. Roda com verificação de JWT da plataforma ligada (padrão).
import { createClient } from 'npm:@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';
import { signStreamToken } from '../_shared/stream-token.ts';
import { extrairDriveFileId } from '../_shared/google-drive.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

// 3h: dá folga pra assistir uma aula inteira sem precisar renovar no meio
// (o player renova sozinho se ainda assim expirar — ver montarPlayerAulaDrive
// no front-end). Token só serve pra UMA aula, então o risco de uma janela
// maior é baixo.
const TOKEN_TTL_SECONDS = 3 * 60 * 60;

function jsonError(origin: string | null, message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  const origin = req.headers.get('Origin');
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders(origin) });
  if (req.method !== 'POST') return jsonError(origin, 'Método não permitido.', 405);

  const jwt = (req.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '');
  if (!jwt) return jsonError(origin, 'Não autenticado.', 401);

  let aulaId: number | string | undefined;
  try {
    ({ aula_id: aulaId } = await req.json());
  } catch {
    return jsonError(origin, 'Corpo da requisição inválido.', 400);
  }
  if (!aulaId) return jsonError(origin, 'aula_id é obrigatório.', 400);

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { data: userData, error: userError } = await supabase.auth.getUser(jwt);
  if (userError || !userData?.user) return jsonError(origin, 'Sessão inválida ou expirada.', 401);

  const { data: usuario, error: usuarioError } = await supabase
    .from('usuarios')
    .select('id, colaborador_id, ativo, perfis(nome)')
    .eq('auth_user_id', userData.user.id)
    .maybeSingle();
  if (usuarioError || !usuario || !usuario.ativo || !usuario.perfis) return jsonError(origin, 'Usuário sem acesso ao sistema.', 403);

  const { data: aula, error: aulaError } = await supabase
    .from('curso_aulas')
    .select('id, id_curso, tipo_video, url_video')
    .eq('id', aulaId)
    .single();
  if (aulaError || !aula) return jsonError(origin, 'Aula não encontrada.', 404);
  if (aula.tipo_video !== 'upload') return jsonError(origin, 'Esta aula não usa vídeo do Drive.', 400);

  const driveFileId = extrairDriveFileId(aula.url_video);
  if (!driveFileId) return jsonError(origin, 'Vídeo desta aula está com o link do Drive mal configurado.', 500);

  const acessoTotal = usuario.perfis.nome === 'Administrador' || usuario.perfis.nome === 'RH';

  if (!acessoTotal) {
    const filtroColuna = usuario.colaborador_id ? 'id_colaborador' : 'id_usuario';
    const filtroValor = usuario.colaborador_id || usuario.id;
    const { data: liberacao } = await supabase
      .from('curso_liberacoes')
      .select('status')
      .eq('id_curso', aula.id_curso)
      .eq(filtroColuna, filtroValor)
      .maybeSingle();
    if (!liberacao || liberacao.status !== 'Liberado') {
      return jsonError(origin, 'Você não tem acesso a este curso.', 403);
    }
  }

  const token = await signStreamToken({
    aid: aula.id,
    exp: Math.floor(Date.now() / 1000) + TOKEN_TTL_SECONDS,
  });

  return new Response(JSON.stringify({ token, expires_in: TOKEN_TTL_SECONDS }), {
    headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
  });
});
