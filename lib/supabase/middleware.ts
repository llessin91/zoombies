import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';
import type { User } from '@supabase/supabase-js';
import { lerEnvSupabase } from './env';

// Renova a sessão do usuário a cada requisição e devolve quem está logado (ou null)
export async function atualizarSessao(
  request: NextRequest,
): Promise<{ resposta: NextResponse; user: User | null }> {
  const { url, chave } = lerEnvSupabase();
  let resposta = NextResponse.next({ request });

  const supabase = createServerClient(url, chave, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(lista: { name: string; value: string; options: CookieOptions }[]) {
        lista.forEach(({ name, value }) => request.cookies.set(name, value));
        resposta = NextResponse.next({ request });
        lista.forEach(({ name, value, options }) => resposta.cookies.set(name, value, options));
      },
    },
  });

  // getUser() confere o token com o servidor do Supabase (mais seguro que getSession)
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return { resposta, user };
}
