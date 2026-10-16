// src/app/(game)/layout.tsx
// Casca do jogo. Segunda camada de proteção (o middleware é a primeira):
// sem sessão volta ao login; sem personagem vai para a criação.

import { redirect } from 'next/navigation';
import { AvisoBanco } from '@/components/game/AvisoBanco';
import { EstadoJogoProvider } from '@/components/game/EstadoJogo';
import { ShellJogo } from '@/components/game/ShellJogo';
import { carregarEstadoPersonagem } from '@/lib/game/carregarEstado';

export const dynamic = 'force-dynamic';

export default async function GameLayout({ children }: { children: React.ReactNode }) {
  const r = await carregarEstadoPersonagem();

  if (r.tipo === 'sem_sessao') redirect('/login');
  if (r.tipo === 'sem_personagem') redirect('/criar-personagem');
  if (r.tipo === 'erro') return <AvisoBanco faltaAtualizar={r.faltaAtualizar} />;

  return (
    <EstadoJogoProvider estadoInicial={r.estado}>
      <ShellJogo>{children}</ShellJogo>
    </EstadoJogoProvider>
  );
}
