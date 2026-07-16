// Token de streaming: um "mini JWT" caseiro, assinado com HMAC-SHA256,
// escopado a UMA aula e com expiração curta. É o que vai na URL do
// <video> (query string) — nunca o access_token de sessão do usuário, que
// tem escopo bem mais amplo e vida mais longa. Mesmo que este token vaze
// (fica em logs de proxy, cache de disco do navegador, histórico), o
// estrago é limitado a assistir uma aula específica até ele expirar.

const encoder = new TextEncoder();

async function getKey(): Promise<CryptoKey> {
  const secret = Deno.env.get('STREAM_TOKEN_SECRET');
  if (!secret) throw new Error('STREAM_TOKEN_SECRET não configurado nos Secrets da Edge Function.');
  return crypto.subtle.importKey('raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign', 'verify']);
}

function toBase64Url(bytes: Uint8Array): string {
  let str = '';
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function fromBase64Url(str: string): Uint8Array {
  const padded = str.replace(/-/g, '+').replace(/_/g, '/').padEnd(str.length + ((4 - (str.length % 4)) % 4), '=');
  const bin = atob(padded);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

export interface StreamTokenPayload {
  aid: number | string; // id da aula (curso_aulas.id)
  exp: number; // epoch seconds
}

export async function signStreamToken(payload: StreamTokenPayload): Promise<string> {
  const key = await getKey();
  const payloadB64 = toBase64Url(encoder.encode(JSON.stringify(payload)));
  const sig = await crypto.subtle.sign('HMAC', key, encoder.encode(payloadB64));
  const sigB64 = toBase64Url(new Uint8Array(sig));
  return `${payloadB64}.${sigB64}`;
}

export async function verifyStreamToken(token: string): Promise<StreamTokenPayload | null> {
  try {
    const [payloadB64, sigB64] = token.split('.');
    if (!payloadB64 || !sigB64) return null;

    const key = await getKey();
    const valid = await crypto.subtle.verify('HMAC', key, fromBase64Url(sigB64), encoder.encode(payloadB64));
    if (!valid) return null;

    const payload = JSON.parse(new TextDecoder().decode(fromBase64Url(payloadB64))) as StreamTokenPayload;
    if (!payload.exp || payload.exp < Math.floor(Date.now() / 1000)) return null;
    return payload;
  } catch {
    return null;
  }
}
