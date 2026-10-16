// src/app/(game)/missoes/page.tsx
// Missões: o servidor monta o catálogo + estado do jogador (bloqueios, esgotamento, faixa de chance).

import { Suspense } from 'react';
import type { Metadata } from 'next';
import { AvisoCarga } from '@/components/game/AvisoCarga';
import { PaginaBase } from '@/components/game/PaginaBase';
import { TelaMissoes } from '@/components/game/TelaMissoes';
import { Skeleton } from '@/components/ui/Skeleton';
import { carregarMundo } from '@/lib/game/mundo';
import { criarClienteServidor } from '@/lib/supabase/server';

export const metadata: Metadata = { title: 'Missões' };
export const dynamic = 'force-dynamic';

export default async function Pagina() {
  const r = await carregarMundo(criarClienteServidor());

  return (
    <PaginaBase titulo="Missões" descricao="Escolha onde arriscar a pele. A chance aparece só como faixa: o resto é com você.">
      {r.ok ? (
        <Suspense fallback={<Skeleton className="h-64 w-full" />}>
          <TelaMissoes mundo={r.mundo} />
        </Suspense>
      ) : (
        <AvisoCarga faltaAtualizar={r.faltaAtualizar} />
      )}
    </PaginaBase>
  );
}
