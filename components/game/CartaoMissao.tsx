'use client';

// src/components/game/CartaoMissao.tsx
// Cartão de missão: nome, local, dificuldade, custo, duração, faixa de chance (nunca o número),
// recompensas possíveis, requisitos e estado (bloqueada, esgotada, disponível).

import { Clock, Hourglass, Lock, MapPin, Star, Zap } from 'lucide-react';
import { Selo, SeloDificuldade, type TomSelo } from '@/components/ui/Selo';
import { Tooltip } from '@/components/ui/Tooltip';
import { CATEGORIAS, FAIXAS, formatarSegundos, type FaixaChance } from '@/lib/game/missoes';
import type { ItemCatalogo, MissaoMundo } from '@/lib/game/mundo';
import { cn } from '@/lib/utils';
import { IconeItem } from './IconeItem';

export const TOM_FAIXA: Record<FaixaChance, TomSelo> = {
  segura: 'verde',
  equilibrada: 'azul',
  arriscada: 'ambar',
  muito_arriscada: 'vermelho',
};

export function SeloFaixa({ faixa }: { faixa: FaixaChance | null }) {
  if (!faixa) return null;
  return (
    <Tooltip conteudo={FAIXAS[faixa].dica}>
      <span tabIndex={0} className="rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde">
        <Selo tom={TOM_FAIXA[faixa]}>{FAIXAS[faixa].rotulo}</Selo>
      </span>
    </Tooltip>
  );
}

interface Props {
  missao: MissaoMundo;
  nomeLocal: string;
  /** Dias do jogo até o local voltar (quando esgotado) */
  diasEsgotado: number | null;
  itens: Record<string, ItemCatalogo>;
  aoAbrir: () => void;
}

export function textoEsgotado(dias: number | null): string {
  if (!dias || dias <= 1) return 'Esgotado, volta em 1 dia do jogo';
  return `Esgotado, volta em ${dias} dias do jogo`;
}

export function CartaoMissao({ missao: m, nomeLocal, diasEsgotado, itens, aoAbrir }: Props) {
  const categoria = CATEGORIAS.find((c) => c.valor === m.categoria)?.rotulo ?? m.categoria;
  // Recompensas possíveis sem repetir item
  const recompensas = Array.from(new Set(m.loot.map((l) => l.item))).slice(0, 6);
  const indisponivel = m.estado !== 'disponivel';

  return (
    <button
      type="button"
      onClick={aoAbrir}
      className={cn(
        'group flex h-full w-full flex-col gap-3 rounded-lg border bg-fundo-1 p-4 text-left shadow-md transition-all',
        'hover:-translate-y-0.5 hover:border-acento-verde/50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde',
        indisponivel ? 'border-borda opacity-70' : 'border-borda',
      )}
    >
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0">
          <h3 className="font-titulo text-xl leading-tight tracking-wide">{m.nome}</h3>
          <p className="mt-0.5 flex items-center gap-1 text-xs text-texto-suave">
            <MapPin className="h-3 w-3 shrink-0" aria-hidden />
            <span className="truncate">
              {nomeLocal}
              {m.ponto && ` · ${m.ponto}`}
            </span>
          </p>
        </div>
        <SeloDificuldade nivel={m.dificuldade} />
      </div>

      <div className="flex flex-wrap items-center gap-1.5">
        <Selo>{categoria}</Selo>
        <Selo tom="ambar" icone={<Zap className="h-3 w-3" aria-hidden />}>
          {m.custoStamina}
        </Selo>
        <Selo icone={<Clock className="h-3 w-3" aria-hidden />}>{formatarSegundos(m.duracaoSegundos)}</Selo>
        <Selo tom="roxo" icone={<Star className="h-3 w-3" aria-hidden />}>
          {m.xp} XP
        </Selo>
        {!indisponivel && <SeloFaixa faixa={m.faixa} />}
      </div>

      <div className="flex items-center gap-2">
        <span className="text-xs text-texto-suave">Pode render:</span>
        <ul className="flex flex-wrap items-center gap-1.5" aria-label="Recompensas possíveis">
          {recompensas.map((slug) => (
            <li key={slug} title={itens[slug]?.nome ?? slug}>
              <IconeItem slug={slug} tipo={itens[slug]?.tipo} />
              <span className="sr-only">{itens[slug]?.nome ?? slug}</span>
            </li>
          ))}
        </ul>
      </div>

      <div className="mt-auto text-xs">
        {m.estado === 'bloqueada' && (
          <p className="flex items-center gap-1.5 text-acento-vermelho">
            <Lock className="h-3.5 w-3.5 shrink-0" aria-hidden />
            {m.motivo ?? 'Bloqueada'}
          </p>
        )}
        {m.estado === 'esgotada' && (
          <p className="flex items-center gap-1.5 text-acento-ambar">
            <Hourglass className="h-3.5 w-3.5 shrink-0" aria-hidden />
            {textoEsgotado(diasEsgotado)}
          </p>
        )}
        {m.estado === 'disponivel' && <p className="text-acento-verde">Disponível</p>}
      </div>
    </button>
  );
}
