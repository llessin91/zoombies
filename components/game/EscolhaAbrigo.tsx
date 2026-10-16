'use client';

// src/components/game/EscolhaAbrigo.tsx
// Escolha do abrigo inicial: cartões com espaços, vantagens e desvantagens (com números),
// "Ver detalhes" e confirmação. Quem valida e grava é o servidor.

import { useState } from 'react';
import { motion, useReducedMotion } from 'framer-motion';
import { Caravan, Check, DoorClosed, Hammer, Home, LayoutGrid, MapPin, Store, X } from 'lucide-react';
import { Botao } from '@/components/ui/Botao';
import { Modal } from '@/components/ui/Modal';
import { Selo } from '@/components/ui/Selo';
import { useToast } from '@/components/ui/Toast';
import { pedirAcao } from '@/lib/api/cliente';
import { descreverDesvantagens, descreverVantagens, type EstadoAbrigo, type OpcaoAbrigo } from '@/lib/game/abrigo';
import { cn } from '@/lib/utils';
import { useEstadoJogo } from './EstadoJogo';

const ICONE_ABRIGO: Record<string, typeof Home> = {
  apartamento_barricado: DoorClosed,
  oficina_abandonada: Hammer,
  porao_mercearia: Store,
  trailer_blindado: Caravan,
};

export function EscolhaAbrigo({ opcoes, aoEscolher }: { opcoes: OpcaoAbrigo[]; aoEscolher: (e: EstadoAbrigo) => void }) {
  const reduzir = useReducedMotion();
  const toast = useToast();
  const { sincronizar } = useEstadoJogo();
  const [detalhe, setDetalhe] = useState<OpcaoAbrigo | null>(null);
  const [confirmar, setConfirmar] = useState<OpcaoAbrigo | null>(null);
  const [enviando, setEnviando] = useState(false);

  async function escolher(o: OpcaoAbrigo) {
    setEnviando(true);
    const r = await pedirAcao<{ estado: EstadoAbrigo }>('/api/abrigo/escolher', { slug: o.slug });
    setEnviando(false);
    if (!r.ok) {
      toast.erro('Não deu certo', r.erro);
      return;
    }
    setConfirmar(null);
    toast.sucesso(`Bem-vindo ao ${o.nome}`, 'Não é muito, mas tem porta.');
    aoEscolher(r.dados.estado);
    void sincronizar();
  }

  return (
    <div className="space-y-4">
      <div className="rounded-lg border border-acento-ambar/40 bg-acento-ambar/5 px-4 py-3 text-sm">
        <p className="font-medium">Escolha onde você vai se esconder.</p>
        <p className="text-texto-suave">Cada abrigo tem espaços para instalações, uma vantagem e um preço. Leia com calma.</p>
      </div>

      <ul className="grid gap-3 md:grid-cols-2">
        {opcoes.map((o, k) => {
          const Icone = ICONE_ABRIGO[o.slug] ?? Home;
          return (
            <motion.li
              key={o.slug}
              initial={reduzir ? false : { opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: k * 0.06 }}
              className="flex flex-col gap-3 rounded-lg border border-borda bg-fundo-1 p-4"
            >
              <div className="flex items-start gap-3">
                <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-lg bg-fundo-2">
                  <Icone className="h-6 w-6 text-acento-ambar" aria-hidden />
                </span>
                <div className="min-w-0">
                  <h3 className="font-titulo text-xl tracking-wide">{o.nome}</h3>
                  <p className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-texto-suave">
                    <span className="flex items-center gap-1">
                      <MapPin className="h-3 w-3" aria-hidden /> {o.local ?? '—'} · {o.regiao ?? '—'}
                    </span>
                    <span className="flex items-center gap-1">
                      <LayoutGrid className="h-3 w-3" aria-hidden /> {o.slots} espaços
                    </span>
                  </p>
                </div>
              </div>
              <ListaProsContras opcao={o} />
              <div className="mt-auto flex justify-end gap-2">
                <Botao variante="fantasma" onClick={() => setDetalhe(o)}>
                  Ver detalhes
                </Botao>
                <Botao onClick={() => setConfirmar(o)}>Escolher</Botao>
              </div>
            </motion.li>
          );
        })}
      </ul>

      {/* Detalhes */}
      <Modal aberto={Boolean(detalhe)} aoFechar={() => setDetalhe(null)} titulo={detalhe?.nome ?? ''}>
        {detalhe && (
          <div className="space-y-4">
            <p className="text-sm text-texto-suave">{detalhe.descricao}</p>
            <div className="flex flex-wrap gap-1.5">
              <Selo icone={<MapPin className="h-3 w-3" aria-hidden />}>{detalhe.local ?? '—'}</Selo>
              <Selo>{detalhe.regiao ?? '—'}</Selo>
              <Selo tom="azul">{detalhe.slots} espaços para instalações</Selo>
            </div>
            <ListaProsContras opcao={detalhe} />
            <div className="flex justify-end gap-2">
              <Botao variante="fantasma" onClick={() => setDetalhe(null)}>
                Fechar
              </Botao>
              <Botao
                onClick={() => {
                  setConfirmar(detalhe);
                  setDetalhe(null);
                }}
              >
                Escolher este
              </Botao>
            </div>
          </div>
        )}
      </Modal>

      {/* Confirmação */}
      <Modal aberto={Boolean(confirmar)} aoFechar={() => !enviando && setConfirmar(null)} titulo="Confirmar abrigo">
        {confirmar && (
          <div className="space-y-4">
            <p className="text-sm">
              Ficar no <strong>{confirmar.nome}</strong>?
            </p>
            <p className="rounded-md border border-acento-ambar/50 bg-acento-ambar/10 px-3 py-2 text-sm">
              Esta escolha vale enquanto você mantiver este abrigo.
            </p>
            <div className="flex justify-end gap-2">
              <Botao variante="fantasma" onClick={() => setConfirmar(null)} disabled={enviando}>
                Voltar
              </Botao>
              <Botao carregando={enviando} onClick={() => escolher(confirmar)}>
                Confirmar
              </Botao>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
}

function ListaProsContras({ opcao }: { opcao: OpcaoAbrigo }) {
  const pros = descreverVantagens(opcao.vantagens);
  const contras = descreverDesvantagens(opcao.desvantagens);
  return (
    <div className="grid gap-2 text-sm sm:grid-cols-2">
      <ul className="space-y-1" aria-label="Vantagens">
        {pros.map((p) => (
          <li key={p} className="flex items-start gap-1.5">
            <Check className="mt-0.5 h-4 w-4 shrink-0 text-acento-verde" aria-hidden />
            {p}
          </li>
        ))}
      </ul>
      <ul className="space-y-1" aria-label="Desvantagens">
        {contras.map((p) => (
          <li key={p} className={cn('flex items-start gap-1.5 text-texto-suave')}>
            <X className="mt-0.5 h-4 w-4 shrink-0 text-acento-vermelho" aria-hidden />
            {p}
          </li>
        ))}
      </ul>
    </div>
  );
}
