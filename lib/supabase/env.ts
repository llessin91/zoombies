// Lê as variáveis públicas do Supabase. Precisam ser acessadas por nome literal para o Next.js embuti-las.
export function lerEnvSupabase(): { url: string; chave: string } {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const chave = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !chave) {
    throw new Error(
      'Faltam NEXT_PUBLIC_SUPABASE_URL e NEXT_PUBLIC_SUPABASE_ANON_KEY. Veja o README (Fase 2, passo das variáveis).',
    );
  }
  return { url, chave };
}
