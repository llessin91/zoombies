'use client';

import { createContext, useCallback, useContext, useMemo, useRef, useState, type ReactNode } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { AlertTriangle, CheckCircle2, Info, X, XCircle } from 'lucide-react';
import { cn } from '@/lib/utils';

type TipoToast = 'sucesso' | 'erro' | 'aviso' | 'info';

interface ItemToast {
  id: number;
  tipo: TipoToast;
  titulo: string;
  texto?: string;
}

interface ToastApi {
  sucesso: (titulo: string, texto?: string) => void;
  erro: (titulo: string, texto?: string) => void;
  aviso: (titulo: string, texto?: string) => void;
  info: (titulo: string, texto?: string) => void;
}

const ToastContexto = createContext<ToastApi | null>(null);

const ESTILOS: Record<TipoToast, { borda: string; icone: typeof Info; cor: string }> = {
  sucesso: { borda: 'border-acento-verde/60', icone: CheckCircle2, cor: 'text-acento-verde' },
  erro: { borda: 'border-acento-vermelho/60', icone: XCircle, cor: 'text-acento-vermelho' },
  aviso: { borda: 'border-acento-ambar/60', icone: AlertTriangle, cor: 'text-acento-ambar' },
  info: { borda: 'border-acento-azul/60', icone: Info, cor: 'text-acento-azul' },
};

export function ToastProvider({ children }: { children: ReactNode }) {
  const [itens, setItens] = useState<ItemToast[]>([]);
  const contador = useRef(0);

  const remover = useCallback((id: number) => setItens((l) => l.filter((i) => i.id !== id)), []);

  const mostrar = useCallback(
    (tipo: TipoToast, titulo: string, texto?: string) => {
      const id = ++contador.current;
      setItens((l) => [...l.slice(-4), { id, tipo, titulo, texto }]); // no máximo 5 empilhados
      setTimeout(() => remover(id), tipo === 'erro' ? 8000 : 5000); // fecha sozinho
    },
    [remover],
  );

  const api = useMemo<ToastApi>(
    () => ({
      sucesso: (t, x) => mostrar('sucesso', t, x),
      erro: (t, x) => mostrar('erro', t, x),
      aviso: (t, x) => mostrar('aviso', t, x),
      info: (t, x) => mostrar('info', t, x),
    }),
    [mostrar],
  );

  return (
    <ToastContexto.Provider value={api}>
      {children}
      <div
        aria-live="polite"
        className="pointer-events-none fixed bottom-24 right-4 z-[60] flex w-[calc(100%-2rem)] max-w-sm flex-col gap-2 lg:bottom-4"
      >
        <AnimatePresence initial={false}>
          {itens.map((t) => {
            const e = ESTILOS[t.tipo];
            const Icone = e.icone;
            return (
              <motion.div
                key={t.id}
                layout
                initial={{ opacity: 0, x: 40 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: 40 }}
                className={cn('pointer-events-auto flex items-start gap-3 rounded-md border bg-fundo-2 p-3 shadow-lg', e.borda)}
              >
                <Icone className={cn('mt-0.5 h-5 w-5 shrink-0', e.cor)} aria-hidden />
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-medium">{t.titulo}</p>
                  {t.texto && <p className="text-xs text-texto-suave">{t.texto}</p>}
                </div>
                <button
                  type="button"
                  onClick={() => remover(t.id)}
                  aria-label="Fechar aviso"
                  className="flex h-8 w-8 items-center justify-center rounded text-texto-suave hover:text-texto"
                >
                  <X className="h-4 w-4" aria-hidden />
                </button>
              </motion.div>
            );
          })}
        </AnimatePresence>
      </div>
    </ToastContexto.Provider>
  );
}

export function useToast(): ToastApi {
  const ctx = useContext(ToastContexto);
  if (!ctx) throw new Error('useToast precisa estar dentro de ToastProvider');
  return ctx;
}
