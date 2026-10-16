// src/app/(criacao)/layout.tsx
// Criação do personagem: fica fora da casca do jogo (sem menus), com a cidade em ruínas ao fundo.
// Quem já tem personagem é mandado para o Início.

import { redirect } from 'next/navigation';
import { AvisoBanco } from '@/components/game/AvisoBanco';
import { CenaRuinas } from '@/components/scenes/CenaRuinas';
import { carregarEstadoPersonagem } from '@/lib/game/carregarEstado';

export const dynamic = 'force-dynamic';

export default async function CriacaoLayout({ children }: { children: React.ReactNode }) {
  const r = await carregarEstadoPersonagem();
  if (r.tipo === 'sem_sessao') redirect('/login');
  if (r.tipo === 'ok') redirect('/inicio');
  if (r.tipo === 'erro') return <AvisoBanco faltaAtualizar={r.faltaAtualizar} />;

  return (
    <>
      <CenaRuinas />
      <main className="relative z-10 mx-auto flex min-h-dvh w-full max-w-2xl flex-col justify-center gap-6 px-4 py-10">
        <p className="text-center font-titulo text-3xl tracking-[0.25em] text-acento-verde">ZOMBIES</p>
        {children}
      </main>
    </>
  );
}
