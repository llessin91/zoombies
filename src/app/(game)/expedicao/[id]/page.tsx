import type { Metadata } from 'next';
import { PaginaBase } from '@/components/game/PaginaBase';
import { Cartao } from '@/components/ui/Cartao';
import { EstadoVazio } from '@/components/ui/Estados';
import { Skeleton } from '@/components/ui/Skeleton';

export const metadata: Metadata = { title: 'Expedição' };

export default function ExpedicaoPage({ params }: { params: { id: string } }) {
  return (
    <PaginaBase
      titulo="Expedição"
      descricao={`Execução da expedição ${params.id} (Fase 5).`}
      migalhas={[{ rotulo: 'Início', href: '/inicio' }, { rotulo: 'Missões', href: '/missoes' }, { rotulo: 'Expedição' }]}
    >
      <Cartao>
        <Skeleton className="h-48 w-full" />
        <EstadoVazio texto="Nenhuma expedição em andamento." detalhe="Cena animada, barra de progresso e log chegam na Fase 5." />
      </Cartao>
    </PaginaBase>
  );
}
