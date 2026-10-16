import { redirect } from 'next/navigation';
import { ShellJogo } from '@/components/game/ShellJogo';
import { criarClienteServidor } from '@/lib/supabase/server';

// Segunda camada de proteção (o middleware é a primeira): sem sessão, volta ao login
export default async function GameLayout({ children }: { children: React.ReactNode }) {
  const supabase = criarClienteServidor();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect('/login');

  const { data: perfil } = await supabase.from('profiles').select('nome_sobrevivente').eq('id', user.id).maybeSingle();

  return <ShellJogo nomeSobrevivente={perfil?.nome_sobrevivente ?? undefined}>{children}</ShellJogo>;
}
