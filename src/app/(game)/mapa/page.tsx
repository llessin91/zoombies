// src/app/(game)/mapa/page.tsx
// Mapa das regiões, desbloqueios, locais e marcador do abrigo.

import type { Metadata } from 'next';
import { AvisoCarga } from '@/components/game/AvisoCarga';
import { MapaRegioes } from '@/components/game/MapaRegioes';
import { PaginaBase } from '@/components/game/PaginaBase';
import { carregarMundo } from '@/lib/game/mundo';
import { criarClienteServidor } from '@/lib/supabase/server';

export const metadata: Metadata = { title: 'Mapa' };
export const dynamic = 'force-dynamic';

export default async function Pagina() {
  const r = await carregarMundo(criarClienteServidor());

  return (
    <PaginaBase titulo="Mapa" descricao="Quatro regiões, trinta e dois lugares e nenhum turista.">
      {r.ok ? <MapaRegioes mundo={r.mundo} /> : <AvisoCarga faltaAtualizar={r.faltaAtualizar} />}
    </PaginaBase>
  );
}
