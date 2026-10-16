'use client';

// src/components/game/FeedAcontecimentos.tsx
// Últimos 10 registros do game_log do jogador.

import { useEffect, useState } from 'react';
import { HeartPulse, Scroll, Star, User } from 'lucide-react';
import { EstadoVazio } from '@/components/ui/Estados';

export interface Acontecimento {
  id: number;
  tipo: string;
  texto: string;
  criado_em: string;
}

const ICONES: Record<string, typeof Star> = {
  nivel: Star,
  personagem: User,
  moral: HeartPulse,
};

function quandoFoi(iso: string, agora: number): string {
  const seg = Math.max(0, Math.round((agora - Date.parse(iso)) / 1000));
  if (seg < 60) return 'agora';
  const min = Math.round(seg / 60);
  if (min < 60) return `há ${min} min`;
  const h = Math.round(min / 60);
  if (h < 24) return `há ${h} h`;
  return new Date(iso).toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' });
}

export function FeedAcontecimentos({ itens }: { itens: Acontecimento[] }) {
  // Só calcula "há X min" no navegador, para não divergir do HTML gerado no servidor
  const [agora, setAgora] = useState<number | null>(null);
  useEffect(() => setAgora(Date.now()), []);

  if (itens.length === 0) return <EstadoVazio compacto texto="Nada aconteceu ainda. Aproveite enquanto dura." />;

  return (
    <ol className="space-y-2">
      {itens.map((i) => {
        const Icone = ICONES[i.tipo] ?? Scroll;
        return (
          <li key={i.id} className="flex items-start gap-3 text-sm">
            <Icone className="mt-0.5 h-4 w-4 shrink-0 text-texto-suave" aria-hidden />
            <span className="flex-1">{i.texto}</span>
            <time dateTime={i.criado_em} className="shrink-0 font-mono text-xs text-texto-suave">
              {agora === null ? '' : quandoFoi(i.criado_em, agora)}
            </time>
          </li>
        );
      })}
    </ol>
  );
}
