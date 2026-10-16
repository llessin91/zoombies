'use client';

import type { ReactNode } from 'react';
import { motion } from 'framer-motion';
import { cn } from '@/lib/utils';

interface CartaoProps {
  titulo?: string;
  subtitulo?: string;
  icone?: ReactNode;
  acao?: ReactNode;
  variante?: 'padrao' | 'fita' | 'perigo' | 'destaque';
  /** Eleva levemente no hover (cartões clicáveis) */
  interativo?: boolean;
  /** Posição na lista: cria a entrada escalonada (stagger) */
  indice?: number;
  className?: string;
  children?: ReactNode;
}

const VARIANTES = {
  padrao: 'border-borda',
  fita: 'border-borda',
  perigo: 'border-acento-vermelho/60',
  destaque: 'border-acento-verde/50',
};

export function Cartao({ titulo, subtitulo, icone, acao, variante = 'padrao', interativo = false, indice = 0, className, children }: CartaoProps) {
  return (
    <motion.section
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3, delay: Math.min(indice, 10) * 0.06 }}
      className={cn(
        'relative rounded-lg border bg-fundo-1 p-4 shadow-md',
        VARIANTES[variante],
        interativo && 'transition-transform duration-150 hover:-translate-y-0.5 hover:border-acento-verde/50',
        className,
      )}
    >
      {variante === 'fita' && (
        <span aria-hidden className="absolute -top-2 left-6 h-4 w-14 -rotate-3 rounded-sm bg-acento-ambar/25" />
      )}
      {(titulo || acao) && (
        <header className="mb-3 flex items-start justify-between gap-3">
          <div className="flex items-center gap-2">
            {icone}
            <div>
              {titulo && <h2 className="font-titulo text-xl tracking-wide">{titulo}</h2>}
              {subtitulo && <p className="text-xs text-texto-suave">{subtitulo}</p>}
            </div>
          </div>
          {acao}
        </header>
      )}
      {children}
    </motion.section>
  );
}
