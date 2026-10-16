import { createBrowserClient } from '@supabase/ssr';
import { lerEnvSupabase } from './env';

// Cliente para uso no navegador (formulários de login, logout)
export function criarClienteNavegador() {
  const { url, chave } = lerEnvSupabase();
  return createBrowserClient(url, chave);
}
