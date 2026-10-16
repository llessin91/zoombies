// src/app/(game)/expedicao/[id]/page.tsx
// Tela da expedição. O servidor devolve o estado atual (inclusive se você fechou a página e voltou).

import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { AvisoCarga } from '@/components/game/AvisoCarga';
import { PaginaBase } from '@/components/game/PaginaBase';
import { TelaExpedicao } from '@/components/game/TelaExpedicao';
import { lerEstadoExpedicao } from '@/lib/game/expedicao';
import { criarClienteServidor } from '@/lib/supabase/server';
import { idExpedicaoSchema } from '@/lib/validacao/expedicao';

export const metadata: Metadata = { title: 'Expedição' };
export const dynamic = 'force-dynamic';

export default async function ExpedicaoPage({ params }: { params: { id: string } }) {
  if (!idExpedicaoSchema.safeParse(params.id).success) notFound();

  const supabase = criarClienteServidor();
  const { data, error } = await supabase.rpc('estado_expedicao', { p_id: params.id });
  if (error?.code === 'P0001') notFound();

  const migalhas = [{ rotulo: 'Início', href: '/inicio' }, { rotulo: 'Missões', href: '/missoes' }, { rotulo: 'Expedição' }];
  if (error) {
    console.error('[estado_expedicao]', error.code, error.message);
    return (
      <PaginaBase titulo="Expedição" migalhas={migalhas}>
        <AvisoCarga faltaAtualizar={['PGRST202', '42883'].includes(error.code ?? '')} />
      </PaginaBase>
    );
  }

  const expedicao = lerEstadoExpedicao(data);
  return (
    <PaginaBase titulo="Expedição" migalhas={migalhas}>
      <TelaExpedicao inicial={expedicao} />
    </PaginaBase>
  );
}
