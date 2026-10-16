'use client';

import { useEffect, useId, useRef, useState, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { AnimatePresence, motion } from 'framer-motion';
import { X } from 'lucide-react';

const FOCAVEIS = 'a[href],button:not([disabled]),textarea,input,select,[tabindex]:not([tabindex="-1"])';

interface ModalProps {
  aberto: boolean;
  aoFechar: () => void;
  titulo: string;
  children: ReactNode;
  /** Modal crítico: não fecha com ESC nem clicando fora, e não mostra o X */
  critico?: boolean;
}

export function Modal({ aberto, aoFechar, titulo, children, critico = false }: ModalProps) {
  const [montado, setMontado] = useState(false);
  const caixa = useRef<HTMLDivElement>(null);
  const fecharRef = useRef(aoFechar);
  fecharRef.current = aoFechar;
  const tituloId = useId();

  useEffect(() => setMontado(true), []);

  useEffect(() => {
    if (!aberto) return;
    const anterior = document.activeElement as HTMLElement | null;
    const overflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';

    // Foco inicial dentro do modal
    const primeiro = caixa.current?.querySelector<HTMLElement>(FOCAVEIS);
    (primeiro ?? caixa.current)?.focus();

    function aoTeclar(e: KeyboardEvent) {
      if (e.key === 'Escape' && !critico) {
        e.stopPropagation();
        fecharRef.current();
        return;
      }
      if (e.key !== 'Tab' || !caixa.current) return;
      // Foco preso: Tab circula só dentro do modal
      const itens = Array.from(caixa.current.querySelectorAll<HTMLElement>(FOCAVEIS));
      if (itens.length === 0) {
        e.preventDefault();
        return;
      }
      const inicio = itens[0];
      const fim = itens[itens.length - 1];
      if (e.shiftKey && document.activeElement === inicio) {
        e.preventDefault();
        fim.focus();
      } else if (!e.shiftKey && document.activeElement === fim) {
        e.preventDefault();
        inicio.focus();
      }
    }

    document.addEventListener('keydown', aoTeclar);
    return () => {
      document.removeEventListener('keydown', aoTeclar);
      document.body.style.overflow = overflow;
      anterior?.focus();
    };
  }, [aberto, critico]);

  if (!montado) return null;

  return createPortal(
    <AnimatePresence>
      {aberto && (
        <motion.div
          key="fundo"
          className="fixed inset-0 z-50 flex items-end justify-center bg-black/70 p-4 sm:items-center"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          onMouseDown={(e) => {
            if (e.target === e.currentTarget && !critico) fecharRef.current();
          }}
        >
          <motion.div
            ref={caixa}
            role="dialog"
            aria-modal="true"
            aria-labelledby={tituloId}
            tabIndex={-1}
            className="w-full max-w-md rounded-lg border border-borda bg-fundo-1 p-5 shadow-2xl outline-none"
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 24 }}
            transition={{ duration: 0.2 }}
          >
            <div className="mb-3 flex items-start justify-between gap-3">
              <h2 id={tituloId} className="font-titulo text-2xl tracking-wide">
                {titulo}
              </h2>
              {!critico && (
                <button
                  type="button"
                  onClick={() => fecharRef.current()}
                  aria-label="Fechar"
                  className="flex h-11 w-11 items-center justify-center rounded-md text-texto-suave hover:bg-fundo-2 hover:text-texto"
                >
                  <X className="h-5 w-5" aria-hidden />
                </button>
              )}
            </div>
            {children}
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>,
    document.body,
  );
}
