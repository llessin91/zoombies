'use client';

import { useId, useState, type ReactNode } from 'react';
import { cn } from '@/lib/utils';

interface TooltipProps {
  conteudo?: string | null;
  children: ReactNode;
  lado?: 'top' | 'bottom';
  className?: string;
}

// Dica que aparece no hover e no foco do teclado
export function Tooltip({ conteudo, children, lado = 'top', className }: TooltipProps) {
  const [aberto, setAberto] = useState(false);
  const id = useId();

  if (!conteudo) return <>{children}</>;

  return (
    <span
      className={cn('relative inline-flex', className)}
      onMouseEnter={() => setAberto(true)}
      onMouseLeave={() => setAberto(false)}
      onFocus={() => setAberto(true)}
      onBlur={() => setAberto(false)}
      aria-describedby={aberto ? id : undefined}
    >
      {children}
      {aberto && (
        <span
          role="tooltip"
          id={id}
          className={cn(
            'pointer-events-none absolute left-1/2 z-50 w-max max-w-[16rem] -translate-x-1/2 rounded border border-borda bg-fundo-2 px-2 py-1 text-xs text-texto shadow-lg',
            lado === 'top' ? 'bottom-full mb-2' : 'top-full mt-2',
          )}
        >
          {conteudo}
        </span>
      )}
    </span>
  );
}
