import { NextResponse, type NextRequest } from 'next/server';
import { criarClienteServidor } from '@/lib/supabase/server';

// Recebe o link do e-mail (confirmação de conta, link mágico, recuperar senha),
// troca o código por uma sessão e leva o jogador ao destino.
export async function GET(request: NextRequest) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get('code');
  const destinoPedido = searchParams.get('next') ?? '/inicio';
  // Só aceita caminhos internos (evita redirecionar para sites de terceiros)
  const destino = destinoPedido.startsWith('/') && !destinoPedido.startsWith('//') ? destinoPedido : '/inicio';

  if (code) {
    const supabase = criarClienteServidor();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) return NextResponse.redirect(`${origin}${destino}`);
  }
  return NextResponse.redirect(`${origin}/login?erro=link`);
}
