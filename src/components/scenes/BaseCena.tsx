// src/components/scenes/BaseCena.tsx
// Peças comuns das cenas de expedição: camadas com parallax (repetidas para o loop não ter emenda)
// e zumbis cambaleando. Só transform/opacity, para ficar leve no celular.

import type { ReactNode } from 'react';
import { cn } from '@/lib/utils';

/** Camada que desliza para a esquerda sem parar. `parada` congela (evento ou fim). */
export function Camada({ children, velocidade, parada, className }: { children: ReactNode; velocidade: 'lento' | 'medio'; parada: boolean; className?: string }) {
  return (
    <div className={cn('absolute inset-x-0 bottom-0 overflow-hidden', className)}>
      <div
        className={cn('flex h-full w-[200%]', velocidade === 'lento' ? 'animate-parallax-lento' : 'animate-parallax-medio')}
        style={{ animationPlayState: parada ? 'paused' : 'running' }}
      >
        <svg viewBox="0 0 800 200" preserveAspectRatio="xMidYMax slice" className="h-full w-1/2">
          {children}
        </svg>
        <svg viewBox="0 0 800 200" preserveAspectRatio="xMidYMax slice" className="h-full w-1/2">
          {children}
        </svg>
      </div>
    </div>
  );
}

function Zumbi({ x, escala, atraso }: { x: number; escala: number; atraso: number }) {
  return (
    <div className="absolute bottom-[4%] animate-deriva-lenta" style={{ left: `${x}%`, animationDelay: `${-atraso}s` }}>
      <svg
        viewBox="0 0 60 100"
        className="origin-bottom animate-cambalear fill-black/80"
        style={{ width: 28 * escala, height: 46 * escala, animationDelay: `${-atraso / 2}s` }}
      >
        <circle cx="20" cy="12" r="8" />
        <rect x="12" y="20" width="16" height="38" rx="4" />
        <rect x="26" y="26" width="28" height="6" rx="3" />
        <rect x="26" y="37" width="24" height="6" rx="3" />
        <rect x="13" y="58" width="8" height="38" rx="3" />
        <rect x="25" y="58" width="8" height="38" rx="3" transform="rotate(10 29 58)" />
      </svg>
    </div>
  );
}

const QUANTIDADE: Record<string, number> = { facil: 2, media: 3, dificil: 5, lendaria: 7 };

/** Mais perigo = mais zumbis, maiores e mais perto */
export function Zumbis({ dificuldade }: { dificuldade: string }) {
  const n = QUANTIDADE[dificuldade] ?? 2;
  return (
    <div className="absolute inset-0">
      {Array.from({ length: n }, (_, i) => (
        <Zumbi key={i} x={8 + ((i * 83) % 84)} escala={0.8 + ((i * 37) % 10) / 20 + n * 0.04} atraso={i * 1.7} />
      ))}
    </div>
  );
}

export interface PropsCena {
  dificuldade: string;
  parada: boolean;
}
