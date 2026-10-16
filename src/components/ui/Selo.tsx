import type { ReactNode } from 'react';
import { cn } from '@/lib/utils';

export type TomSelo = 'neutro' | 'verde' | 'ambar' | 'vermelho' | 'azul' | 'roxo' | 'laranja';

const TONS: Record<TomSelo, string> = {
  neutro: 'border-borda bg-fundo-2 text-texto-suave',
  verde: 'border-acento-verde/60 bg-acento-verde/10 text-acento-verde',
  ambar: 'border-acento-ambar/60 bg-acento-ambar/10 text-acento-ambar',
  vermelho: 'border-acento-vermelho/60 bg-acento-vermelho/10 text-acento-vermelho',
  azul: 'border-acento-azul/60 bg-acento-azul/10 text-acento-azul',
  roxo: 'border-acento-roxo/60 bg-acento-roxo/10 text-acento-roxo',
  laranja: 'border-acento-laranja/60 bg-acento-laranja/10 text-acento-laranja',
};

interface SeloProps {
  tom?: TomSelo;
  icone?: ReactNode;
  children: ReactNode;
  className?: string;
}

export function Selo({ tom = 'neutro', icone, children, className }: SeloProps) {
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded border px-2 py-0.5 text-xs font-medium leading-5',
        TONS[tom],
        className,
      )}
    >
      {icone}
      {children}
    </span>
  );
}

export type Dificuldade = 'facil' | 'media' | 'dificil' | 'lendaria';

const DIFICULDADES: Record<Dificuldade, { rotulo: string; tom: TomSelo }> = {
  facil: { rotulo: 'Fácil', tom: 'verde' },
  media: { rotulo: 'Média', tom: 'ambar' },
  dificil: { rotulo: 'Difícil', tom: 'laranja' },
  lendaria: { rotulo: 'Lendária', tom: 'roxo' },
};

export function SeloDificuldade({ nivel }: { nivel: Dificuldade }) {
  const d = DIFICULDADES[nivel];
  return <Selo tom={d.tom}>{d.rotulo}</Selo>;
}

export type Raridade = 'comum' | 'incomum' | 'raro' | 'epico' | 'lendario';

const RARIDADES: Record<Raridade, { rotulo: string; tom: TomSelo }> = {
  comum: { rotulo: 'Comum', tom: 'neutro' },
  incomum: { rotulo: 'Incomum', tom: 'verde' },
  raro: { rotulo: 'Raro', tom: 'azul' },
  epico: { rotulo: 'Épico', tom: 'roxo' },
  lendario: { rotulo: 'Lendário', tom: 'ambar' },
};

export function SeloRaridade({ nivel }: { nivel: Raridade }) {
  const r = RARIDADES[nivel];
  return <Selo tom={r.tom}>{r.rotulo}</Selo>;
}
