'use client';

import { forwardRef, type ButtonHTMLAttributes, type ReactNode } from 'react';
import { Loader2, Zap } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Selo } from './Selo';
import { Tooltip } from './Tooltip';

export type VarianteBotao = 'primario' | 'secundario' | 'perigo' | 'fantasma' | 'acao';

interface BotaoProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variante?: VarianteBotao;
  carregando?: boolean;
  /** Se preenchido, o botão fica desabilitado e mostra este motivo na dica */
  motivoDesabilitado?: string;
  /** Só para variante "acao": mostra o custo de stamina em um selo */
  custoStamina?: number;
  icone?: ReactNode;
}

const BASE =
  'inline-flex min-h-[44px] select-none items-center justify-center gap-2 rounded-md border px-4 text-sm font-medium outline-none transition-all duration-150 focus-visible:ring-2 focus-visible:ring-acento-verde focus-visible:ring-offset-2 focus-visible:ring-offset-fundo-0';

const VARIANTES: Record<VarianteBotao, { base: string; ativo: string }> = {
  primario: {
    base: 'border-acento-verde bg-acento-verde/20 text-texto',
    ativo:
      'hover:bg-acento-verde/30 hover:shadow-[0_0_14px_rgb(var(--acento-verde)/0.35)] active:translate-y-px active:scale-[0.98]',
  },
  secundario: {
    base: 'border-borda bg-transparent text-texto',
    ativo: 'hover:border-texto-suave hover:bg-fundo-2 active:translate-y-px active:scale-[0.98]',
  },
  perigo: {
    base: 'border-acento-vermelho bg-acento-vermelho/20 text-texto',
    ativo:
      'hover:bg-acento-vermelho/30 hover:shadow-[0_0_14px_rgb(var(--acento-vermelho)/0.35)] active:translate-y-px active:scale-[0.98]',
  },
  fantasma: {
    base: 'border-transparent bg-transparent text-texto-suave',
    ativo: 'hover:bg-fundo-2 hover:text-texto active:translate-y-px',
  },
  acao: {
    base: 'min-h-[56px] border-acento-verde bg-acento-verde/20 px-6 font-titulo text-lg uppercase tracking-wider text-texto',
    ativo: 'animate-pulso-suave hover:bg-acento-verde/30 active:translate-y-px active:scale-[0.98]',
  },
};

export const Botao = forwardRef<HTMLButtonElement, BotaoProps>(function Botao(
  { variante = 'primario', carregando = false, motivoDesabilitado, custoStamina, icone, disabled, onClick, className, children, type = 'button', ...resto },
  ref,
) {
  const bloqueado = Boolean(disabled) || Boolean(motivoDesabilitado) || carregando;
  const v = VARIANTES[variante];

  // aria-disabled (e não "disabled") mantém o botão focável e deixa a dica aparecer
  return (
    <Tooltip conteudo={bloqueado && !carregando ? motivoDesabilitado : null}>
      <button
        ref={ref}
        type={type}
        aria-disabled={bloqueado || undefined}
        aria-busy={carregando || undefined}
        onClick={(e) => {
          if (bloqueado) {
            e.preventDefault();
            return;
          }
          onClick?.(e);
        }}
        className={cn(BASE, v.base, bloqueado ? 'cursor-not-allowed opacity-50 saturate-50' : v.ativo, className)}
        {...resto}
      >
        {carregando ? (
          <>
            <Loader2 className="h-4 w-4 animate-spin" aria-hidden />
            <span className="sr-only">Carregando</span>
          </>
        ) : (
          icone
        )}
        {children}
        {variante === 'acao' && custoStamina !== undefined && (
          <Selo tom="ambar" icone={<Zap className="h-3 w-3" aria-hidden />}>
            {custoStamina}
          </Selo>
        )}
      </button>
    </Tooltip>
  );
});
