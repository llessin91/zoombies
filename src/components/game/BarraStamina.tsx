'use client';

// src/components/game/BarraStamina.tsx
// Stamina com brilho âmbar e contagem regressiva para o próximo ponto.

import { Zap } from 'lucide-react';
import { Barra } from '@/components/ui/Barra';
import { formatarDuracao } from '@/lib/game/stamina';
import { cn } from '@/lib/utils';
import { useStaminaProjetada } from './EstadoJogo';

export function BarraStamina({ compacta = false, className }: { compacta?: boolean; className?: string }) {
  const s = useStaminaProjetada();

  if (compacta) {
    return (
      <div className={cn('flex shrink-0 items-center gap-1.5 md:gap-2', className)}>
        <Zap className="h-4 w-4 shrink-0 text-acento-ambar" aria-hidden />
        <Barra valor={s.atual} max={s.maxima} tom="ambar" altura="sm" brilho rotulo="Stamina" ocultarRotulo className="w-10 shrink-0 sm:w-14 md:w-24" />
        <span className="whitespace-nowrap font-mono text-xs" title={s.proximoEm !== null ? `+1 em ${formatarDuracao(s.proximoEm)}` : 'Cheia'}>
          {s.atual}/{s.maxima}
        </span>
      </div>
    );
  }

  return (
    <div className={cn('space-y-1.5', className)}>
      <div className="flex items-center justify-between text-sm">
        <span className="flex items-center gap-2">
          <Zap className="h-4 w-4 text-acento-ambar" aria-hidden />
          Stamina
        </span>
        <span className="font-mono">
          {s.atual}/{s.maxima}
        </span>
      </div>
      <Barra valor={s.atual} max={s.maxima} tom="ambar" brilho rotulo="Stamina" ocultarRotulo />
      <p className="text-xs text-texto-suave">
        {s.proximoEm === null ? (
          'Cheia. Hora de gastar.'
        ) : (
          <>
            +1 em <span className="font-mono text-texto">{formatarDuracao(s.proximoEm)}</span>
            {s.encheEm !== null && s.encheEm > s.proximoEm && (
              <>
                {' '}
                · cheia em <span className="font-mono text-texto">{formatarDuracao(s.encheEm)}</span>
              </>
            )}
          </>
        )}
      </p>
    </div>
  );
}
