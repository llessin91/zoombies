'use client';

import { useId, useRef, type KeyboardEvent, type ReactNode } from 'react';
import { cn } from '@/lib/utils';

export interface AbaItem {
  id: string;
  rotulo: string;
  /** Bolinha de notificação */
  indicador?: boolean;
}

interface AbasProps {
  abas: AbaItem[];
  valor: string;
  aoMudar: (id: string) => void;
  rotuloLista: string;
  children: ReactNode;
}

export function Abas({ abas, valor, aoMudar, rotuloLista, children }: AbasProps) {
  const base = useId();
  const botoes = useRef<Array<HTMLButtonElement | null>>([]);

  function aoTeclar(e: KeyboardEvent<HTMLButtonElement>, indice: number) {
    let novo = indice;
    if (e.key === 'ArrowRight') novo = (indice + 1) % abas.length;
    else if (e.key === 'ArrowLeft') novo = (indice - 1 + abas.length) % abas.length;
    else if (e.key === 'Home') novo = 0;
    else if (e.key === 'End') novo = abas.length - 1;
    else return;
    e.preventDefault();
    aoMudar(abas[novo].id);
    botoes.current[novo]?.focus();
  }

  return (
    <div>
      <div role="tablist" aria-label={rotuloLista} className="flex gap-1 overflow-x-auto border-b border-borda">
        {abas.map((aba, i) => {
          const ativa = aba.id === valor;
          return (
            <button
              key={aba.id}
              ref={(el) => {
                botoes.current[i] = el;
              }}
              type="button"
              role="tab"
              id={`${base}-aba-${aba.id}`}
              aria-selected={ativa}
              aria-controls={`${base}-painel-${aba.id}`}
              tabIndex={ativa ? 0 : -1}
              onClick={() => aoMudar(aba.id)}
              onKeyDown={(e) => aoTeclar(e, i)}
              className={cn(
                'relative min-h-[44px] whitespace-nowrap border-b-2 px-4 text-sm font-medium transition-colors',
                ativa ? 'border-acento-verde text-texto' : 'border-transparent text-texto-suave hover:text-texto',
              )}
            >
              {aba.rotulo}
              {aba.indicador && (
                <span aria-label="Novidade" className="absolute right-1 top-2 h-2 w-2 rounded-full bg-acento-vermelho" />
              )}
            </button>
          );
        })}
      </div>
      <div role="tabpanel" id={`${base}-painel-${valor}`} aria-labelledby={`${base}-aba-${valor}`} className="pt-4">
        {children}
      </div>
    </div>
  );
}
