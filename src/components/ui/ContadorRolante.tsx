'use client';

// src/components/ui/ContadorRolante.tsx
// Número que "rola" até o novo valor quando muda (XP, recursos, estatísticas).

import { useEffect, useRef, useState } from 'react';
import { animate, useReducedMotion } from 'framer-motion';
import { cn } from '@/lib/utils';

export function ContadorRolante({ valor, className }: { valor: number; className?: string }) {
  const reduzir = useReducedMotion();
  const [mostrado, setMostrado] = useState(valor);
  const anterior = useRef(valor);

  useEffect(() => {
    if (reduzir) {
      setMostrado(valor);
      anterior.current = valor;
      return;
    }
    const controle = animate(anterior.current, valor, {
      duration: 0.6,
      ease: 'easeOut',
      onUpdate: (v) => setMostrado(Math.round(v)),
    });
    anterior.current = valor;
    return () => controle.stop();
  }, [valor, reduzir]);

  return <span className={cn('font-mono tabular-nums', className)}>{mostrado.toLocaleString('pt-BR')}</span>;
}
