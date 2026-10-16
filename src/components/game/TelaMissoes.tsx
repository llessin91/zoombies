'use client';

// src/components/game/TelaMissoes.tsx
// Lista de missões com filtros (região, dificuldade, categoria, só disponíveis) e preparação.

import { useMemo, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { SearchX } from 'lucide-react';
import { EstadoVazio } from '@/components/ui/Estados';
import type { Dificuldade } from '@/lib/game/config';
import { CATEGORIAS, DIFICULDADES, type Categoria } from '@/lib/game/missoes';
import type { MundoJogador } from '@/lib/game/mundo';
import { CartaoMissao } from './CartaoMissao';
import { ModalPreparacao } from './ModalPreparacao';

const SELECT =
  'min-h-[44px] w-full rounded-md border border-borda bg-fundo-1 px-3 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde';

export function TelaMissoes({ mundo }: { mundo: MundoJogador }) {
  const params = useSearchParams();
  const regiaoInicial = params.get('regiao') ?? '';
  const [regiao, setRegiao] = useState(mundo.regioes.some((r) => r.slug === regiaoInicial) ? regiaoInicial : '');
  const [dificuldade, setDificuldade] = useState<Dificuldade | ''>('');
  const [categoria, setCategoria] = useState<Categoria | ''>('');
  const [soDisponiveis, setSoDisponiveis] = useState(false);
  const [aberta, setAberta] = useState<string | null>(null);

  const nomeLocal = useMemo(() => new Map(mundo.locais.map((l) => [l.slug, l.nome])), [mundo.locais]);
  const esgotado = useMemo(() => new Map(mundo.locais.map((l) => [l.slug, l.esgotadoDias])), [mundo.locais]);

  const filtradas = mundo.missoes.filter(
    (m) =>
      (!regiao || m.regiao === regiao) &&
      (!dificuldade || m.dificuldade === dificuldade) &&
      (!categoria || m.categoria === categoria) &&
      (!soDisponiveis || m.estado === 'disponivel'),
  );
  const disponiveis = mundo.missoes.filter((m) => m.estado === 'disponivel').length;
  const missaoAberta = mundo.missoes.find((m) => m.slug === aberta) ?? null;

  function limpar() {
    setRegiao('');
    setDificuldade('');
    setCategoria('');
    setSoDisponiveis(false);
  }

  return (
    <div className="space-y-4">
      <form
        aria-label="Filtros"
        onSubmit={(e) => e.preventDefault()}
        className="grid grid-cols-2 gap-3 rounded-lg border border-borda bg-fundo-1/60 p-3 lg:grid-cols-[1fr_1fr_1fr_auto]"
      >
        <label className="text-xs text-texto-suave">
          Região
          <select value={regiao} onChange={(e) => setRegiao(e.target.value)} className={SELECT}>
            <option value="">Todas</option>
            {mundo.regioes.map((r) => (
              <option key={r.slug} value={r.slug}>
                {r.nome}
                {!r.liberada ? ' (bloqueada)' : ''}
              </option>
            ))}
          </select>
        </label>
        <label className="text-xs text-texto-suave">
          Dificuldade
          <select value={dificuldade} onChange={(e) => setDificuldade(e.target.value as Dificuldade | '')} className={SELECT}>
            <option value="">Todas</option>
            {DIFICULDADES.map((d) => (
              <option key={d.valor} value={d.valor}>
                {d.rotulo}
              </option>
            ))}
          </select>
        </label>
        <label className="col-span-2 text-xs text-texto-suave lg:col-span-1">
          Categoria
          <select value={categoria} onChange={(e) => setCategoria(e.target.value as Categoria | '')} className={SELECT}>
            <option value="">Todas</option>
            {CATEGORIAS.map((c) => (
              <option key={c.valor} value={c.valor}>
                {c.rotulo}
              </option>
            ))}
          </select>
        </label>
        <label className="col-span-2 flex min-h-[44px] items-center gap-2 self-end text-sm lg:col-span-1">
          <input
            type="checkbox"
            checked={soDisponiveis}
            onChange={(e) => setSoDisponiveis(e.target.checked)}
            className="h-4 w-4 accent-[rgb(var(--acento-verde))]"
          />
          Somente disponíveis
        </label>
      </form>

      <p className="text-xs text-texto-suave" aria-live="polite">
        Mostrando {filtradas.length} de {mundo.missoes.length} missões · {disponiveis} disponíveis agora
      </p>

      {filtradas.length === 0 ? (
        <div className="rounded-lg border border-borda bg-fundo-1">
          <EstadoVazio
            icone={<SearchX className="h-8 w-8" aria-hidden />}
            texto="Nenhuma missão com esses filtros."
            detalhe="Nem os zumbis passaram por aqui."
          />
          <div className="pb-6 text-center">
            <button type="button" onClick={limpar} className="text-sm text-acento-verde hover:underline">
              Limpar filtros
            </button>
          </div>
        </div>
      ) : (
        <ul className="grid gap-3 md:grid-cols-2 2xl:grid-cols-3">
          {filtradas.map((m) => (
            <li key={m.slug}>
              <CartaoMissao
                missao={m}
                nomeLocal={nomeLocal.get(m.local) ?? m.local}
                diasEsgotado={esgotado.get(m.local) ?? null}
                itens={mundo.itens}
                aoAbrir={() => setAberta(m.slug)}
              />
            </li>
          ))}
        </ul>
      )}

      <ModalPreparacao
        key={aberta ?? 'nenhuma'}
        missao={missaoAberta}
        nomeLocal={missaoAberta ? nomeLocal.get(missaoAberta.local) ?? '' : ''}
        diasEsgotado={missaoAberta ? esgotado.get(missaoAberta.local) ?? null : null}
        itens={mundo.itens}
        mochila={mundo.mochila}
        cargaMaxima={mundo.cargaMaxima}
        aoFechar={() => setAberta(null)}
      />
    </div>
  );
}
