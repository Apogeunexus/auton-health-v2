// Vercel Edge Function — proxy do auton.db (hospedado em GitHub Release,
// grande demais para o Vercel armazenar diretamente e cross-origin para
// fetch direto do browser).
//
// O Edge runtime segue o redirect 302 do GitHub, faz stream do binário
// (~121 MB) e devolve como same-origin para o browser — sem CORS.

export const config = {
  runtime: 'edge',
};

const RELEASE_URL =
  'https://github.com/Apogeunexus/auton-health-v2/releases/download/v1.0.0/auton.db';

export default async function handler() {
  const upstream = await fetch(RELEASE_URL, {
    // fetch do Edge segue redirects por padrão; explicitando por clareza
    redirect: 'follow',
  });

  if (!upstream.ok) {
    return new Response(
      `Falha ao buscar auton.db (upstream ${upstream.status})`,
      { status: 502, headers: { 'content-type': 'text/plain' } },
    );
  }

  // Stream direto da resposta do upstream para o browser
  return new Response(upstream.body, {
    status: 200,
    headers: {
      'content-type': 'application/octet-stream',
      'cache-control': 'public, max-age=31536000, immutable',
      // sem Access-Control necessário — same-origin
    },
  });
}
