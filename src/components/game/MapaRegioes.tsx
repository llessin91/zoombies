'use client';

// src/components/game/MapaRegioes.tsx
// Mapa estilizado das 4 regiões. Bloqueadas ficam com névoa e cadeado e mostram o requisito.
// Clicar numa região lista os locais com dificuldades e estado. O abrigo aparece como casinha.

import { useState } from 'react';
import Link from 'next/link';
import { Home, Hourglass, Lock, MapPin, Target } from 'lucide-react';
import { Cartao } from '@/components/ui/Cartao';
import { Selo, SeloDificuldade } from '@/components/ui/Selo';
import type { Dificuldade } from '@/lib/game/config';
import { DIFICULDADES } from '@/lib/game/missoes';
import type { MundoJogador } from '@/lib/game/mundo';
import { cn } from '@/lib/utils';
import { textoEsgotado } from './CartaoMissao';

interface Desenho {
  pontos: string;
  rotulo: [number, number];
  /** Nome em linhas, para caber no mapa */
  linhas: string[];
  cor: string;
  locais: [number, number][];
}

// Formas das regiões (viewBox 600 × 420) e posição dos 8 locais de cada uma, na ordem do catálogo
const DESENHOS: Record<string, Desenho> = {
  centro_urbano: {
    pontos: '20,30 280,20 300,230 150,200 20,220',
    rotulo: [150, 105],
    linhas: ['CENTRO', 'URBANO'],
    cor: '--acento-azul',
    locais: [[60, 60], [130, 50], [210, 55], [255, 75], [70, 160], [140, 150], [210, 165], [262, 190]],
  },
  zona_militar_cientifica: {
    pontos: '280,20 580,20 580,250 300,230',
    rotulo: [440, 105],
    linhas: ['ZONA MILITAR', 'E CIENTÍFICA'],
    cor: '--acento-roxo',
    locais: [[330, 60], [400, 50], [470, 60], [540, 55], [340, 180], [410, 160], [480, 180], [545, 205]],
  },
  periferia: {
    pontos: '20,220 150,200 300,230 310,400 20,400',
    rotulo: [160, 300],
    linhas: ['PERIFERIA'],
    cor: '--acento-verde',
    locais: [[60, 255], [130, 240], [200, 255], [265, 265], [70, 355], [140, 345], [210, 365], [275, 375]],
  },
  zona_industrial: {
    pontos: '300,230 580,250 580,400 310,400',
    rotulo: [445, 320],
    linhas: ['ZONA', 'INDUSTRIAL'],
    cor: '--acento-laranja',
    locais: [[340, 270], [410, 270], [480, 285], [545, 285], [350, 365], [420, 350], [490, 370], [550, 375]],
  },
};

const ORDEM_DIF: Dificuldade[] = DIFICULDADES.map((d) => d.valor);

export function MapaRegioes({ mundo }: { mundo: MundoJogador }) {
  const regiaoDoAbrigo = mundo.locais.find((l) => l.ehAbrigo)?.regiao;
  const [selecionada, setSelecionada] = useState<string>(regiaoDoAbrigo ?? 'periferia');

  const regiao = mundo.regioes.find((r) => r.slug === selecionada) ?? mundo.regioes[0];
  const locaisDaRegiao = mundo.locais.filter((l) => l.regiao === regiao?.slug);

  return (
    <div className="grid gap-4 xl:grid-cols-[minmax(0,1.4fr)_minmax(0,1fr)]">
      <div className="self-start overflow-hidden rounded-lg border border-borda bg-fundo-1 xl:sticky xl:top-20">
        <svg viewBox="0 0 600 420" className="h-auto w-full" role="group" aria-label="Mapa das regiões">
          <defs>
            {/* Névoa das regiões bloqueadas */}
            <filter id="nevoa" x="0" y="0" width="100%" height="100%">
              <feTurbulence type="fractalNoise" baseFrequency="0.012" numOctaves="3" seed="7" />
              <feColorMatrix values="0 0 0 0 0.55  0 0 0 0 0.58  0 0 0 0 0.56  0 0 0 0.9 -0.15" />
            </filter>
            {Object.entries(DESENHOS).map(([slug, d]) => (
              <clipPath key={slug} id={`clip-${slug}`}>
                <polygon points={d.pontos} />
              </clipPath>
            ))}
          </defs>

          {/* Fundo: estradas */}
          <rect width="600" height="420" fill="rgb(var(--fundo-0))" />
          <g stroke="rgb(var(--borda))" strokeWidth="3" fill="none" strokeDasharray="10 8" aria-hidden>
            <path d="M0 215 C 150 190, 320 240, 600 245" />
            <path d="M290 0 C 300 120, 290 300, 310 420" />
            <path d="M80 420 C 140 300, 120 120, 200 0" />
          </g>

          {mundo.regioes.map((r) => {
            const d = DESENHOS[r.slug];
            if (!d) return null;
            const ativa = r.slug === selecionada;
            const locais = mundo.locais.filter((l) => l.regiao === r.slug);
            return (
              <g
                key={r.slug}
                role="button"
                tabIndex={0}
                aria-pressed={ativa}
                aria-label={`${r.nome}: ${r.liberada ? 'liberada' : r.motivo ?? 'bloqueada'}`}
                onClick={() => setSelecionada(r.slug)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    setSelecionada(r.slug);
                  }
                }}
                className="cursor-pointer outline-none [&:focus-visible>polygon]:stroke-[rgb(var(--texto))]"
              >
                <polygon
                  points={d.pontos}
                  fill={`rgb(var(${d.cor}) / ${ativa ? 0.22 : 0.1})`}
                  stroke={`rgb(var(${d.cor}) / ${ativa ? 0.95 : 0.45})`}
                  strokeWidth={ativa ? 3 : 1.5}
                  className="transition-all duration-200"
                />

                {/* Locais */}
                {locais.map((l, i) => {
                  const p = d.locais[i];
                  if (!p) return null;
                  const cor = !r.liberada ? '--texto-suave' : l.esgotadoDias ? '--acento-ambar' : d.cor;
                  return (
                    <g key={l.slug} aria-hidden>
                      <circle cx={p[0]} cy={p[1]} r={l.ehAbrigo ? 9 : 5} fill={`rgb(var(${cor}) / 0.9)`} stroke="rgb(var(--fundo-0))" strokeWidth="2" />
                      {l.ehAbrigo && (
                        <path
                          d={`M${p[0] - 5} ${p[1] + 1} L${p[0]} ${p[1] - 5} L${p[0] + 5} ${p[1] + 1} V${p[1] + 5} H${p[0] - 5} Z`}
                          fill="rgb(var(--fundo-0))"
                        />
                      )}
                    </g>
                  );
                })}

                {/* Névoa e cadeado */}
                {!r.liberada && (
                  <g aria-hidden>
                    <rect width="600" height="420" filter="url(#nevoa)" clipPath={`url(#clip-${r.slug})`} className="animate-pulso-suave" />
                    <g transform={`translate(${d.rotulo[0] - 12} ${d.rotulo[1] - 46})`} fill="none" stroke="rgb(var(--texto))" strokeWidth="2.5">
                      <rect x="2" y="10" width="20" height="15" rx="2" fill="rgb(var(--fundo-1) / 0.8)" />
                      <path d="M6 10 V6 a6 6 0 0 1 12 0 V10" />
                    </g>
                  </g>
                )}

                <text
                  x={d.rotulo[0]}
                  y={d.rotulo[1]}
                  textAnchor="middle"
                  className="font-titulo"
                  fontSize="20"
                  letterSpacing="2"
                  fill="rgb(var(--texto))"
                  style={{ paintOrder: 'stroke', stroke: 'rgb(var(--fundo-0) / 0.85)', strokeWidth: 4 }}
                  aria-hidden
                >
                  {d.linhas.map((linha, i) => (
                    <tspan key={linha} x={d.rotulo[0]} dy={i === 0 ? 0 : 21}>
                      {linha}
                    </tspan>
                  ))}
                </text>
                {!r.liberada && r.motivo && (
                  <text
                    x={d.rotulo[0]}
                    y={d.rotulo[1] + 21 * (d.linhas.length - 1) + 20}
                    textAnchor="middle"
                    fontSize="12"
                    fill="rgb(var(--texto))"
                    style={{ paintOrder: 'stroke', stroke: 'rgb(var(--fundo-0) / 0.85)', strokeWidth: 3 }}
                    aria-hidden
                  >
                    {r.motivo}
                  </text>
                )}
              </g>
            );
          })}
        </svg>
        <ul className="flex flex-wrap gap-x-4 gap-y-1 border-t border-borda px-3 py-2 text-xs text-texto-suave">
          <li className="flex items-center gap-1.5">
            <span className="h-2.5 w-2.5 rounded-full bg-acento-verde" aria-hidden /> Disponível
          </li>
          <li className="flex items-center gap-1.5">
            <span className="h-2.5 w-2.5 rounded-full bg-acento-ambar" aria-hidden /> Esgotado por um tempo
          </li>
          <li className="flex items-center gap-1.5">
            <span className="h-2.5 w-2.5 rounded-full bg-texto-suave" aria-hidden /> Bloqueado
          </li>
          <li className="flex items-center gap-1.5">
            <Home className="h-3.5 w-3.5" aria-hidden /> Seu abrigo
          </li>
        </ul>
      </div>

      {regiao && (
        <Cartao
          key={regiao.slug}
          titulo={regiao.nome}
          subtitulo={regiao.liberada ? 'Liberada' : regiao.motivo ?? 'Bloqueada'}
          icone={regiao.liberada ? <MapPin className="h-5 w-5 text-acento-verde" aria-hidden /> : <Lock className="h-5 w-5 text-acento-vermelho" aria-hidden />}
          acao={
            <Link
              href={`/missoes?regiao=${regiao.slug}`}
              className="inline-flex min-h-[44px] items-center gap-1.5 rounded-md border border-borda px-3 text-sm hover:bg-fundo-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde"
            >
              <Target className="h-4 w-4" aria-hidden />
              Missões
            </Link>
          }
        >
          <p className="mb-3 text-sm text-texto-suave">{regiao.descricao}</p>
          <ul className="space-y-2">
            {locaisDaRegiao.map((l) => {
              const missoes = mundo.missoes.filter((m) => m.local === l.slug);
              const difs = ORDEM_DIF.filter((d) => missoes.some((m) => m.dificuldade === d));
              const estado = !regiao.liberada ? 'bloqueado' : l.esgotadoDias ? 'esgotado' : 'disponivel';
              return (
                <li key={l.slug} className="rounded-md border border-borda bg-fundo-0/40 px-3 py-2">
                  <div className="flex flex-wrap items-center justify-between gap-x-3 gap-y-0.5">
                    <p className="flex items-center gap-1.5 text-sm font-medium">
                      {l.ehAbrigo ? <Home className="h-4 w-4 text-acento-verde" aria-label="Seu abrigo" /> : <MapPin className="h-4 w-4 text-texto-suave" aria-hidden />}
                      {l.nome}
                    </p>
                    <span
                      className={cn(
                        'flex shrink-0 items-center gap-1 text-xs',
                        estado === 'disponivel' && 'text-acento-verde',
                        estado === 'esgotado' && 'text-acento-ambar',
                        estado === 'bloqueado' && 'text-texto-suave',
                      )}
                    >
                      {estado === 'bloqueado' && <Lock className="h-3 w-3" aria-hidden />}
                      {estado === 'esgotado' && <Hourglass className="h-3 w-3" aria-hidden />}
                      {estado === 'disponivel' ? 'Disponível' : estado === 'esgotado' ? textoEsgotado(l.esgotadoDias) : 'Bloqueado'}
                    </span>
                  </div>
                  <p className="mt-0.5 text-xs text-texto-suave">{l.descricao}</p>
                  <div className="mt-1.5 flex flex-wrap items-center gap-1">
                    {difs.map((d) => (
                      <SeloDificuldade key={d} nivel={d} />
                    ))}
                    <Selo>{missoes.length} missões</Selo>
                  </div>
                </li>
              );
            })}
          </ul>
        </Cartao>
      )}
    </div>
  );
}
