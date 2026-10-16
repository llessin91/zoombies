'use client';

// src/components/game/CartaoExpedicaoAtiva.tsx
// Expedição em andamento (ou com saque esperando decisão), com botão "Retomar".

import Link from 'next/link';
import { Hourglass } from 'lucide-react';
import { EstadoVazio } from '@/components/ui/Estados';
import { cn } from '@/lib/utils';
import { useAgoraServidor, useEstadoJogo } from './EstadoJogo';

export function CartaoExpedicaoAtiva({ compacto = false }: { compacto?: boolean }) {
  const { estado } = useEstadoJogo();
  const agora = useAgoraServidor();
  const e = estado.expedicao;

  if (!e) {
    if (compacto) return null;
    return <EstadoVazio compacto texto="Nenhuma expedição em andamento." detalhe="Escolha uma missão para sair." />;
  }

  const restante = Math.max(0, Math.ceil((Date.parse(e.termina_em) - agora) / 1000));
  const situacao = e.loot_pendente
    ? 'Saque esperando você decidir o que levar'
    : e.estado === 'aguardando_evento'
      ? 'Uma decisão espera por você'
      : restante > 0
        ? `Termina em ${restante} s`
        : 'Chegou ao fim: veja o resultado';

  return (
    <div className={cn('flex flex-wrap items-center justify-between gap-3', compacto && 'rounded-lg border border-acento-ambar/50 bg-acento-ambar/10 p-3')}>
      <div className="flex items-center gap-2">
        <Hourglass className="h-5 w-5 text-acento-ambar" aria-hidden />
        <div>
          <p className="text-sm font-medium">{e.missao}</p>
          <p className="text-xs text-texto-suave">{situacao}</p>
        </div>
      </div>
      <Link
        href={`/expedicao/${e.id}`}
        className="inline-flex min-h-[44px] items-center rounded-md border border-acento-verde bg-acento-verde/20 px-4 text-sm font-medium hover:bg-acento-verde/30 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde"
      >
        Retomar
      </Link>
    </div>
  );
}
