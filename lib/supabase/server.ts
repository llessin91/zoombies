import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { lerEnvSupabase } from './env';

// Cliente para uso no servidor (layouts, route handlers). Lê e grava a sessão nos cookies.
export function criarClienteServidor() {
  const { url, chave } = lerEnvSupabase();
  const armazem = cookies();

  return createServerClient(url, chave, {
    cookies: {
      getAll() {
        return armazem.getAll();
      },
      setAll(lista: { name: string; value: string; options: CookieOptions }[]) {
        try {
          lista.forEach(({ name, value, options }) => armazem.set(name, value, options));
        } catch {
          // Chamado de um Server Component (somente leitura): o middleware renova a sessão, pode ignorar.
        }
      },
    },
  });
}
