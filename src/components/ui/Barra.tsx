'use client';

import { motion } from 'framer-motion';
import { cn } from '@/lib/utils';

export type TomBarra = 'verde' | 'ambar' | 'vermelho' | 'azul' | 'roxo' | 'moral';
type TomFixo = Exclude<TomBarra, 'moral'>;

const FUNDO: Record<TomFixo, string> = {
  verde: 'bg-acento-verde',
  ambar: 'bg-acento-ambar',
  vermelho: 'bg-acento-vermelho',
  azul: 'bg-acento-azul',
  roxo: 'bg-acento-roxo',
};

const VARIAVEL: Record<TomFixo, string> = {
  verde: '--acento-verde',
  ambar: '--acento-ambar',
  vermelho: '--acento-vermelho',
  azul: '--acento-azul',
  roxo: '--acento-roxo',
};

const ALTURA = { sm: 'h-1.5', md: 'h-3', lg: 'h-5' };

// Moral: verde (alta), âmbar (média), vermelho (baixa)
function tomDaMoral(pct: number): TomFixo {
  if (pct >= 60) return 'verde';
  if (pct >= 30) return 'ambar';
  return 'vermelho';
}

interface BarraProps {
  valor: number;
  max: number;
  tom?: TomBarra;
  rotulo?: string;
  /** Mantém o rótulo só para leitores de tela */
  ocultarRotulo?: boolean;
  mostrarValor?: boolean;
  /** Posição de 0 a 1 de um marcador (ex.: ponto do evento, sem revelar o tipo) */
  marcador?: number;
  altura?: 'sm' | 'md' | 'lg';
  brilho?: boolean;
  className?: string;
}

export function Barra({ valor, max, tom = 'verde', rotulo, ocultarRotulo = false, mostrarValor = false, marcador, altura = 'md', brilho = false, className }: BarraProps) {
  const pct = max > 0 ? Math.min(100, Math.max(0, (valor / max) * 100)) : 0;
  const tomFinal: TomFixo = tom === 'moral' ? tomDaMoral(pct) : tom;
  const mostrarCabecalho = (rotulo && !ocultarRotulo) || mostrarValor;

  return (
    <div className={cn('w-full', className)}>
      {mostrarCabecalho && (
        <div className="mb-1 flex items-center justify-between text-xs text-texto-suave">
          <span>{ocultarRotulo ? '' : rotulo}</span>
          {mostrarValor && (
            <span className="font-mono text-texto">
              {Math.round(valor)}/{max}
            </span>
          )}
        </div>
      )}
      <div
        role="progressbar"
        aria-label={rotulo}
        aria-valuemin={0}
        aria-valuemax={max}
        aria-valuenow={Math.round(valor)}
        className={cn('relative rounded-full border border-borda bg-fundo-0', ALTURA[altura])}
      >
        <motion.div
          className={cn('h-full rounded-full', FUNDO[tomFinal])}
          initial={{ width: 0 }}
          animate={{ width: `${pct}%` }}
          transition={{ duration: 0.6, ease: 'easeOut' }}
          style={brilho ? { boxShadow: `0 0 10px rgb(var(${VARIAVEL[tomFinal]}) / 0.6)` } : undefined}
        />
        {marcador !== undefined && (
          <span
            aria-hidden
            className="absolute top-[-2px] h-[calc(100%+4px)] w-0.5 bg-texto/80"
            style={{ left: `${marcador * 100}%` }}
          />
        )}
      </div>
    </div>
  );
}
