'use client';

// src/components/scenes/CenaExpedicao.tsx
// Escolhe a cena da região e carrega só ela (carregamento preguiçoso).

import dynamic from 'next/dynamic';
import type { PropsCena } from './BaseCena';

const carregando = () => <div aria-hidden className="absolute inset-0 animate-pulse bg-fundo-1" />;

const CENAS = {
  periferia: dynamic(() => import('./CenaPeriferia'), { ssr: false, loading: carregando }),
  centro_urbano: dynamic(() => import('./CenaCentro'), { ssr: false, loading: carregando }),
  zona_industrial: dynamic(() => import('./CenaIndustrial'), { ssr: false, loading: carregando }),
  zona_militar_cientifica: dynamic(() => import('./CenaMilitar'), { ssr: false, loading: carregando }),
};

export function CenaExpedicao({ regiao, ...props }: PropsCena & { regiao: string }) {
  const Cena = CENAS[regiao as keyof typeof CENAS] ?? CENAS.periferia;
  return <Cena {...props} />;
}
