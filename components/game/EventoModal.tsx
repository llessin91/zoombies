'use client';

// src/components/game/EventoModal.tsx
// Evento no meio da expedição: texto e 2 a 3 opções. A barra fica parada enquanto você decide.
// Risco e recompensa aparecem como ícones (1 a 3), nunca como números de chance.

import { Gem, Lock, Skull, Zap } from 'lucide-react';
import { Modal } from '@/components/ui/Modal';
import { Selo } from '@/components/ui/Selo';
import { Tooltip } from '@/components/ui/Tooltip';
import { ATRIBUTOS } from '@/lib/game/atributos';
import type { EstadoExpedicao } from '@/lib/game/expedicao';
import { cn } from '@/lib/utils';
import { IconeItem } from './IconeItem';

type Evento = NonNullable<EstadoExpedicao['evento']>;

function Icones({ quantos, tipo }: { quantos: number; tipo: 'risco' | 'recompensa' }) {
  const Icone = tipo === 'risco' ? Skull : Gem;
  const rotulo = tipo === 'risco' ? 'Risco' : 'Recompensa';
  return (
    <span className="flex items-center gap-0.5" aria-label={`${rotulo}: ${quantos} de 3`}>
      {[1, 2, 3].map((i) => (
        <Icone
          key={i}
          aria-hidden
          className={cn('h-3.5 w-3.5', i <= quantos ? (tipo === 'risco' ? 'text-acento-vermelho' : 'text-acento-ambar') : 'text-borda')}
        />
      ))}
    </span>
  );
}

interface Props {
  evento: Evento | null;
  enviando: number | null;
  erro: string | null;
  aoEscolher: (indice: number) => void;
}

export function EventoModal({ evento, enviando, erro, aoEscolher }: Props) {
  if (!evento) {
    return (
      <Modal aberto={false} aoFechar={() => undefined} titulo="">
        {null}
      </Modal>
    );
  }
  const prazo = new Date(evento.prazo_em).toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });

  return (
    <Modal aberto aoFechar={() => undefined} titulo={evento.titulo} critico largura="lg">
      <p className="mb-4 text-sm leading-relaxed">{evento.texto}</p>
      <ul className="space-y-2">
        {evento.opcoes.map((o) => {
          const nomeAtributo = o.requisito ? ATRIBUTOS.find((a) => a.chave === o.requisito?.atributo)?.nome ?? o.requisito.atributo : null;
          const faltaRequisito = o.requisito ? !o.requisito.ok : false;
          const faltaItem = o.custo?.item ? o.custo.ok === false : false;
          const bloqueada = faltaRequisito || faltaItem;
          const motivo = faltaRequisito
            ? `Requer ${nomeAtributo} ${o.requisito?.valor}`
            : faltaItem
              ? `Você não tem ${o.custo?.nome ?? o.custo?.item} na mochila`
              : null;
          const carregando = enviando === o.indice;
          return (
            <li key={o.indice}>
              <Tooltip conteudo={motivo} className="block w-full">
                <button
                  type="button"
                  onClick={() => !bloqueada && enviando === null && aoEscolher(o.indice)}
                  aria-disabled={bloqueada || enviando !== null || undefined}
                  className={cn(
                    'w-full rounded-lg border p-3 text-left transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde',
                    bloqueada ? 'cursor-not-allowed border-borda opacity-50' : 'border-borda hover:border-acento-verde/60 hover:bg-fundo-2',
                    carregando && 'animate-pulse',
                  )}
                >
                  <div className="flex items-start justify-between gap-2">
                    <p className="flex items-center gap-1.5 font-medium">
                      {bloqueada && <Lock className="h-4 w-4 text-texto-suave" aria-hidden />}
                      {o.titulo}
                    </p>
                    <div className="flex shrink-0 items-center gap-2">
                      <Icones quantos={o.risco} tipo="risco" />
                      <Icones quantos={o.recompensa} tipo="recompensa" />
                    </div>
                  </div>
                  {o.descricao && <p className="mt-1 text-sm text-texto-suave">{o.descricao}</p>}
                  {(o.custo || o.requisito) && (
                    <div className="mt-2 flex flex-wrap gap-1.5">
                      {o.custo?.item && (
                        <Selo tom={faltaItem ? 'vermelho' : 'neutro'} icone={<IconeItem slug={o.custo.item} className="h-3 w-3" />}>
                          Gasta {o.custo.qtd ?? 1} {o.custo.nome ?? o.custo.item}
                        </Selo>
                      )}
                      {o.custo?.stamina !== undefined && (
                        <Selo tom="ambar" icone={<Zap className="h-3 w-3" aria-hidden />}>
                          {o.custo.stamina} stamina
                        </Selo>
                      )}
                      {o.requisito && (
                        <Selo tom={faltaRequisito ? 'vermelho' : 'azul'}>
                          {nomeAtributo} {o.requisito.valor}
                        </Selo>
                      )}
                    </div>
                  )}
                </button>
              </Tooltip>
            </li>
          );
        })}
      </ul>
      {erro && (
        <p role="alert" className="mt-3 rounded-md border border-acento-vermelho/60 bg-acento-vermelho/10 px-3 py-2 text-sm">
          {erro}
        </p>
      )}
      <p className="mt-3 text-xs text-texto-suave">Pode fechar o jogo: a decisão espera. Se não decidir até {prazo}, a opção mais cautelosa acontece sozinha.</p>
    </Modal>
  );
}
