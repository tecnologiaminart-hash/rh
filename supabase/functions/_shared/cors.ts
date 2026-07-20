// Origens autorizadas a chamar estas Edge Functions via navegador. Antes
// era '*' (qualquer site na internet) — restrito à origem de produção do
// site. Adicione aqui se o site passar a rodar em outro domínio também.
const ALLOWED_ORIGINS = [
  'https://tecnologiaminart-hash.github.io',
];

function allowedOrigin(origin: string | null): string {
  return origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
}

export function corsHeaders(origin: string | null) {
  return {
    'Access-Control-Allow-Origin': allowedOrigin(origin),
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  };
}

export function streamCorsHeaders(origin: string | null) {
  return {
    'Access-Control-Allow-Origin': allowedOrigin(origin),
    'Access-Control-Allow-Headers': 'range',
    'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
    'Vary': 'Origin',
  };
}
