import { NextResponse, type NextRequest } from 'next/server';
import { atualizarSessao } from '@/lib/supabase/middleware';

// Telas que não exigem login
function ehPublica(caminho: string): boolean {
  return caminho === '/login' || caminho === '/cadastro' || caminho.startsWith('/auth/');
}

export async function middleware(request: NextRequest) {
  if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY) {
    return new NextResponse(
      'Faltam as variáveis NEXT_PUBLIC_SUPABASE_URL e NEXT_PUBLIC_SUPABASE_ANON_KEY. Veja o README (Fase 2).',
      { status: 500 },
    );
  }

  const { resposta, user } = await atualizarSessao(request);
  const caminho = request.nextUrl.pathname;

  const ir = (destino: string) => {
    const url = request.nextUrl.clone();
    url.pathname = destino;
    url.search = '';
    const redirecionamento = NextResponse.redirect(url);
    // Mantém os cookies de sessão renovados
    resposta.cookies.getAll().forEach((c) => redirecionamento.cookies.set(c));
    return redirecionamento;
  };

  // Ações (api) sem sessão: responde com erro em vez de mandar para a tela de login
  if (!user && caminho.startsWith('/api/')) {
    return NextResponse.json({ ok: false, erro: 'Sessão expirada. Entre de novo.' }, { status: 401 });
  }
  if (!user && !ehPublica(caminho)) return ir('/login');
  if (user && (caminho === '/login' || caminho === '/cadastro')) return ir('/inicio');

  return resposta;
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|manifest.webmanifest|sw.js|icons/|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)',
  ],
};
