// Autenticação na Google Drive API via Service Account (OAuth2 JWT Bearer
// Flow), implementada na mão com Web Crypto — sem depender da lib
// googleapis (pesada e nem sempre amigável no runtime de Edge Functions).
// O access_token obtido fica em cache em memória (nível de módulo) e é
// reaproveitado entre invocações da função enquanto o isolate ficar "quente",
// evitando bater no endpoint de token do Google a cada request de vídeo.

interface CachedToken {
  accessToken: string;
  expiresAt: number; // epoch seconds
}

let cachedToken: CachedToken | null = null;

const encoder = new TextEncoder();

function toBase64Url(bytes: Uint8Array): string {
  let str = '';
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToBinaryDer(pem: string): ArrayBuffer {
  const body = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s+/g, '');
  const bin = atob(body);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes.buffer;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    'pkcs8',
    pemToBinaryDer(pem),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

async function buildSignedAssertion(clientEmail: string, privateKeyPem: string): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: clientEmail,
    scope: 'https://www.googleapis.com/auth/drive.readonly',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };

  const headerB64 = toBase64Url(encoder.encode(JSON.stringify(header)));
  const claimsB64 = toBase64Url(encoder.encode(JSON.stringify(claims)));
  const signingInput = `${headerB64}.${claimsB64}`;

  const key = await importPrivateKey(privateKeyPem);
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, encoder.encode(signingInput));
  return `${signingInput}.${toBase64Url(new Uint8Array(signature))}`;
}

// Retorna um access_token OAuth2 válido pra chamar a Google Drive API.
export async function getDriveAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt - 60 > now) {
    return cachedToken.accessToken;
  }

  const clientEmail = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_EMAIL');
  const rawPrivateKey = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY');
  if (!clientEmail || !rawPrivateKey) {
    throw new Error('GOOGLE_SERVICE_ACCOUNT_EMAIL / GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY não configurados nos Secrets.');
  }
  // No dashboard de Secrets a chave é colada como uma linha só, com "\n"
  // literais no lugar das quebras de linha reais do PEM — precisa desfazer
  // isso antes de importar a chave.
  const privateKeyPem = rawPrivateKey.replace(/\\n/g, '\n');

  const assertion = await buildSignedAssertion(clientEmail, privateKeyPem);

  const resp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  if (!resp.ok) {
    const body = await resp.text().catch(() => '');
    throw new Error(`Falha ao autenticar com a Service Account do Google (${resp.status}): ${body}`);
  }

  const data = await resp.json();
  cachedToken = { accessToken: data.access_token, expiresAt: now + data.expires_in };
  return cachedToken.accessToken;
}

export function extrairDriveFileId(url: string | null | undefined): string | null {
  if (!url) return null;
  const m = String(url).match(/\/d\/([a-zA-Z0-9_-]+)/) || String(url).match(/[?&]id=([a-zA-Z0-9_-]+)/);
  return m ? m[1] : null;
}
