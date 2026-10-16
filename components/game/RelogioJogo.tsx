'use client';

// src/components/game/RelogioJogo.tsx
// Dia e hora do jogo, contados a partir da criação do personagem.

import { Clock } from 'lucide-react';
import { relogioDoJogo } from '@/lib/game/tempo';
import { cn } from '@/lib/utils';
import { useAgoraServidor, useEstadoJogo } from './EstadoJogo';

export function useRelogioJogo() {
  const { estado } = useEstadoJogo();
  // A cada 5 s reais passam 2 minutos do jogo (no padrão de 1 dia por hora)
  const agora = useAgoraServidor(5000);
  return relogioDoJogo(Date.parse(estado.criado_em), agora, estado.dias_jogo_por_hora_real, estado.hora_inicial);
}

export function RelogioJogo({ className }: { className?: string }) {
  const r = useRelogioJogo();
  return (
    <span className={cn('flex items-center gap-1.5 text-sm text-texto-suave', className)}>
      <Clock className="h-4 w-4" aria-hidden />
      <span className="font-mono" aria-label={`Dia ${r.dia} do jogo, ${r.hora} horas e ${r.minuto} minutos`}>
        {r.texto}
      </span>
    </span>
  );
}
