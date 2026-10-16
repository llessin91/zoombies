'use client';

import { forwardRef, useId, type InputHTMLAttributes } from 'react';
import { cn } from '@/lib/utils';

interface CampoProps extends InputHTMLAttributes<HTMLInputElement> {
  rotulo: string;
  erro?: string;
  dica?: string;
}

export const Campo = forwardRef<HTMLInputElement, CampoProps>(function Campo(
  { rotulo, erro, dica, id, className, ...resto },
  ref,
) {
  const gerado = useId();
  const campoId = id ?? gerado;
  const descId = `${campoId}-desc`;

  return (
    <div className="space-y-1">
      <label htmlFor={campoId} className="block text-sm text-texto-suave">
        {rotulo}
      </label>
      <input
        ref={ref}
        id={campoId}
        aria-invalid={erro ? true : undefined}
        aria-describedby={erro || dica ? descId : undefined}
        className={cn(
          'min-h-[44px] w-full rounded-md border bg-fundo-0 px-3 text-sm text-texto outline-none placeholder:text-texto-suave/60 focus-visible:ring-2 focus-visible:ring-acento-verde',
          erro ? 'border-acento-vermelho' : 'border-borda',
          className,
        )}
        {...resto}
      />
      {(erro || dica) && (
        <p id={descId} className={cn('text-xs', erro ? 'text-acento-vermelho' : 'text-texto-suave')}>
          {erro ?? dica}
        </p>
      )}
    </div>
  );
});

export function CampoCaixa({ rotulo, erro, id, ...resto }: Omit<CampoProps, 'dica' | 'type'>) {
  const gerado = useId();
  const campoId = id ?? gerado;
  return (
    <div className="space-y-1">
      <label htmlFor={campoId} className="flex min-h-[44px] cursor-pointer items-start gap-3 text-sm">
        <input
          id={campoId}
          type="checkbox"
          aria-invalid={erro ? true : undefined}
          className="mt-1 h-5 w-5 accent-[rgb(var(--acento-verde))]"
          {...resto}
        />
        <span>{rotulo}</span>
      </label>
      {erro && <p className="text-xs text-acento-vermelho">{erro}</p>}
    </div>
  );
}
