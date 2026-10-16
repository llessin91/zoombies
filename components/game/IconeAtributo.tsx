// src/components/game/IconeAtributo.tsx
// Ícones SVG simples, feitos à mão, para os seis atributos.

import type { ChaveAtributo } from '@/lib/game/atributos';
import { cn } from '@/lib/utils';

const DESENHOS: Record<ChaveAtributo, JSX.Element> = {
  // Haltere
  forca: (
    <>
      <path d="M6 8v8M18 8v8M3 10v4M21 10v4" />
      <path d="M6 12h12" />
    </>
  ),
  // Pegadas em movimento
  agilidade: (
    <>
      <path d="M4 17l4-5-2-4 5-2 3 4 4 1" />
      <path d="M8 12l3 3-2 5" />
      <path d="M2 7h3M1 11h3" />
    </>
  ),
  // Olho
  percepcao: (
    <>
      <path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12z" />
      <circle cx="12" cy="12" r="3" />
    </>
  ),
  // Cruz médica
  medicina: (
    <>
      <rect x="3" y="3" width="18" height="18" rx="4" />
      <path d="M12 8v8M8 12h8" />
    </>
  ),
  // Chave inglesa
  engenharia: (
    <path d="M14.5 5.5a4 4 0 0 0-5 5L4 16l4 4 5.5-5.5a4 4 0 0 0 5-5l-2.5 2.5-2.5-.5-.5-2.5z" />
  ),
  // Bandeira
  lideranca: (
    <>
      <path d="M5 21V4" />
      <path d="M5 4h11l-2 4 2 4H5" />
    </>
  ),
};

const CORES: Record<ChaveAtributo, string> = {
  forca: 'text-acento-vermelho',
  agilidade: 'text-acento-ambar',
  percepcao: 'text-acento-azul',
  medicina: 'text-acento-verde',
  engenharia: 'text-acento-laranja',
  lideranca: 'text-acento-roxo',
};

export function IconeAtributo({ chave, className }: { chave: ChaveAtributo; className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.8}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
      className={cn('h-6 w-6 shrink-0', CORES[chave], className)}
    >
      {DESENHOS[chave]}
    </svg>
  );
}
