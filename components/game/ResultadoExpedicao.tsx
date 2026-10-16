'use client';

// src/components/game/ResultadoExpedicao.tsx
// Resultado: animação de sucesso total, parcial ou fracasso; XP, saque, ferimentos, moral, stamina;
// "o que levar" quando o saque passa da capacidade; botões de volta.

import { useState } from 'react';
import Link from 'next/link';
import { motion, useReducedMotion } from 'framer-motion';
import { Backpack, HeartPulse, PackageOpen, Skull, Star, Swords, ThumbsDown, Trophy, UserPlus, Zap } from 'lucide-react';
import { Barra } from '@/components/ui/Barra';
import { Botao } from '@/components/ui/Botao';
import { Cartao } from '@/components/ui/Cartao';
import { SeloRaridade, type Raridade } from '@/components/ui/Selo';
import { pesoTotal, validarEscolhaLoot, type EstadoExpedicao } from '@/lib/game/expedicao';
import { cn } from '@/lib/utils';
import { BRILHO_RARIDADE, IconeItem } from './IconeItem';

type Resultado = NonNullable<EstadoExpedicao['resultado']>;

const DESFECHOS = {
  total: { titulo: 'Sucesso total', icone: Trophy, cor: 'text-acento-verde', borda: 'border-acento-verde/60', brilho: '--acento-verde' },
  parcial: { titulo: 'Sucesso parcial', icone: PackageOpen, cor: 'text-acento-ambar', borda: 'border-acento-ambar/60', brilho: '--acento-ambar' },
  fracasso: { titulo: 'Fracasso', icone: ThumbsDown, cor: 'text-acento-vermelho', borda: 'border-acento-vermelho/60', brilho: '--acento-vermelho' },
} as const;


interface Props {
  expedicao: EstadoExpedicao;
  aoConfirmarLoot: (escolha: Record<string, number>) => Promise<string | null>;
}

export function ResultadoExpedicao({ expedicao: e, aoConfirmarLoot }: Props) {
  const r = e.resultado as Resultado;
  const reduzir = useReducedMotion();
  const d = DESFECHOS[r.desfecho];
  const Icone = d.icone;
  const pendente = r.excesso && !e.loot_entregue;

  // "O que levar": começa com tudo e o jogador vai tirando
  const [escolha, setEscolha] = useState<Record<string, number>>(() => Object.fromEntries(r.loot.map((l) => [l.item, l.qtd])));
  const [enviando, setEnviando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const pesoEscolhido = pesoTotal(r.loot.map((l) => ({ item: l.item, qtd: escolha[l.item] ?? 0, peso: l.peso })));
  const problema = pendente ? validarEscolhaLoot(r.loot, escolha, r.carga_disponivel) : null;
  const levado = r.levado ? new Map(r.levado.map((l) => [l.item, l.qtd])) : null;

  async function confirmar() {
    setEnviando(true);
    setErro(await aoConfirmarLoot(escolha));
    setEnviando(false);
  }

  return (
    <div className="space-y-4">
      <motion.div
        initial={reduzir ? false : { scale: 0.85, opacity: 0 }}
        animate={r.desfecho === 'fracasso' && !reduzir ? { scale: 1, opacity: 1, x: [0, -8, 8, -5, 5, 0] } : { scale: 1, opacity: 1 }}
        transition={{ duration: 0.6 }}
        className={cn('flex items-center gap-4 rounded-lg border bg-fundo-1 p-5', d.borda)}
        style={{ boxShadow: `0 0 30px rgb(var(${d.brilho}) / 0.25)` }}
        role="status"
      >
        <Icone className={cn('h-12 w-12 shrink-0', d.cor)} aria-hidden />
        <div>
          <h2 className={cn('font-titulo text-3xl tracking-wide', d.cor)}>{d.titulo}</h2>
          <p className="text-sm text-texto-suave">{r.texto}</p>
        </div>
      </motion.div>

      <dl className="grid grid-cols-2 gap-2 sm:grid-cols-3">
        {[
          { rotulo: 'XP ganho', valor: `+${r.xp_ganho}`, icone: Star, cor: 'text-acento-roxo' },
          { rotulo: 'Moral', valor: r.moral > 0 ? `+${r.moral}` : `${r.moral}`, icone: HeartPulse, cor: r.moral >= 0 ? 'text-acento-verde' : 'text-acento-vermelho' },
          { rotulo: 'Stamina gasta', valor: `${r.stamina_gasta}`, icone: Zap, cor: 'text-acento-ambar' },
          { rotulo: 'Ferimentos', valor: r.ferido ? `Ferido (${r.ferimentos})` : r.ferimentos ? `${r.ferimentos}` : 'Nenhum', icone: Skull, cor: r.ferido ? 'text-acento-vermelho' : 'text-texto-suave' },
          { rotulo: 'Zumbis abatidos', valor: `${r.zumbis}`, icone: Swords, cor: 'text-texto-suave' },
          ...(r.arma_durabilidade !== null ? [{ rotulo: 'Durabilidade da arma', valor: `${r.arma_durabilidade}`, icone: Swords, cor: r.arma_durabilidade > 0 ? 'text-texto-suave' : 'text-acento-vermelho' }] : []),
        ].map(({ rotulo, valor, icone: I, cor }, i) => (
          <motion.div
            key={rotulo}
            initial={reduzir ? false : { opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 + i * 0.07 }}
            className="rounded-md border border-borda bg-fundo-1 px-3 py-2"
          >
            <dt className="flex items-center gap-1.5 text-xs text-texto-suave">
              <I className={cn('h-3.5 w-3.5', cor)} aria-hidden />
              {rotulo}
            </dt>
            <dd className="font-mono text-lg">{valor}</dd>
          </motion.div>
        ))}
      </dl>

      {r.evento?.titulo && (
        <Cartao>
          <p className="text-xs text-texto-suave">Evento: {r.evento.titulo}</p>
          <p className="text-sm">
            <span className="font-medium">{r.evento.opcao}.</span> {r.evento.texto}
          </p>
        </Cartao>
      )}

      {r.recruta_encontrado && (
        <Cartao variante="destaque">
          <p className="flex items-center gap-2 text-sm">
            <UserPlus className="h-4 w-4 text-acento-verde" aria-hidden />
            Alguém quer ir com você para o abrigo. Recrutas chegam na Fase 8; por enquanto, isso conta nas estatísticas.
          </p>
        </Cartao>
      )}

      <Cartao titulo={pendente ? 'O que levar?' : 'Saque'} icone={<Backpack className="h-5 w-5 text-texto-suave" aria-hidden />}>
        {r.loot.length === 0 ? (
          <p className="text-sm text-texto-suave">Nada para trazer desta vez.</p>
        ) : (
          <ul className="space-y-2">
            {r.loot.map((l, i) => {
              const qtd = pendente ? escolha[l.item] ?? 0 : levado ? levado.get(l.item) ?? 0 : l.qtd;
              return (
                <motion.li
                  key={l.item}
                  initial={reduzir ? false : { opacity: 0, scale: 0.9 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ delay: 0.5 + i * 0.08 }}
                  className="flex items-center gap-3 rounded-md border border-borda bg-fundo-0/40 px-3 py-2"
                >
                  <span className={cn('flex h-9 w-9 items-center justify-center rounded-md bg-fundo-2', BRILHO_RARIDADE[l.raridade ?? 'comum'])}>
                    <IconeItem slug={l.item} tipo={l.tipo ?? undefined} className="h-5 w-5" />
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="text-sm">{l.nome ?? l.item}</p>
                    <p className="text-xs text-texto-suave">peso {l.peso} cada</p>
                  </div>
                  {l.raridade && l.raridade !== 'comum' && <SeloRaridade nivel={l.raridade as Raridade} />}
                  {pendente ? (
                    <div className="flex items-center gap-1">
                      <button
                        type="button"
                        aria-label={`Deixar 1 ${l.nome ?? l.item}`}
                        onClick={() => setEscolha((s) => ({ ...s, [l.item]: Math.max(0, (s[l.item] ?? 0) - 1) }))}
                        className="h-9 w-9 rounded-md border border-borda hover:bg-fundo-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde"
                      >
                        −
                      </button>
                      <span className="w-12 text-center font-mono">
                        {qtd}/{l.qtd}
                      </span>
                      <button
                        type="button"
                        aria-label={`Levar mais 1 ${l.nome ?? l.item}`}
                        onClick={() => setEscolha((s) => ({ ...s, [l.item]: Math.min(l.qtd, (s[l.item] ?? 0) + 1) }))}
                        className="h-9 w-9 rounded-md border border-borda hover:bg-fundo-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde"
                      >
                        +
                      </button>
                    </div>
                  ) : (
                    <span className="font-mono text-lg">×{qtd}</span>
                  )}
                </motion.li>
              );
            })}
          </ul>
        )}

        {pendente && (
          <div className="mt-4 space-y-2">
            <p className="text-sm text-acento-ambar">Passou da sua capacidade de carga. Escolha o que deixar para trás.</p>
            <div className="flex items-center justify-between text-sm">
              <span>Peso</span>
              <span className={cn('font-mono', pesoEscolhido > r.carga_disponivel && 'text-acento-vermelho')}>
                {pesoEscolhido} / {r.carga_disponivel}
              </span>
            </div>
            <Barra valor={pesoEscolhido} max={r.carga_disponivel || 1} tom={pesoEscolhido > r.carga_disponivel ? 'vermelho' : 'verde'} rotulo="Peso escolhido" ocultarRotulo />
            {erro && (
              <p role="alert" className="text-sm text-acento-vermelho">
                {erro}
              </p>
            )}
            <div className="flex justify-end">
              <Botao onClick={confirmar} carregando={enviando} motivoDesabilitado={problema ?? undefined}>
                Levar isto
              </Botao>
            </div>
          </div>
        )}
        {!pendente && r.loot.length > 0 && <p className="mt-3 text-xs text-texto-suave">Já está na sua mochila.</p>}
      </Cartao>

      <div className="flex flex-col gap-2 sm:flex-row sm:justify-end">
        <Link
          href="/inventario"
          className="inline-flex min-h-[44px] items-center justify-center rounded-md border border-borda px-4 text-sm hover:bg-fundo-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde"
        >
          Ver inventário
        </Link>
        <Botao variante="secundario" motivoDesabilitado="Local esgotado por enquanto. Escolha outra missão.">
          Repetir missão
        </Botao>
        <Link
          href="/abrigo"
          className="inline-flex min-h-[44px] items-center justify-center rounded-md border border-acento-verde bg-acento-verde/20 px-4 text-sm font-medium hover:bg-acento-verde/30 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde"
        >
          Voltar ao abrigo
        </Link>
      </div>
    </div>
  );
}
