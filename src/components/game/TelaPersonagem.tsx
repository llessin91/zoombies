'use client';

// src/components/game/TelaPersonagem.tsx
// Tela Personagem: nível, XP, stamina, moral, atributos, equipamento e estatísticas.

import { Crosshair, HeartPulse, Info, Star, Swords } from 'lucide-react';
import { Barra } from '@/components/ui/Barra';
import { Cartao } from '@/components/ui/Cartao';
import { ContadorRolante } from '@/components/ui/ContadorRolante';
import { Selo } from '@/components/ui/Selo';
import { Tooltip } from '@/components/ui/Tooltip';
import { faixaMoral } from '@/lib/game/formulas';
import { BarraStamina } from './BarraStamina';
import { useEstadoJogo } from './EstadoJogo';
import { PainelAtributos } from './PainelAtributos';

const EXPLICACAO_MORAL =
  'Moral vai de 0 a 100 e não recebe pontos. Sobe com sucessos em missões fáceis e com descanso no abrigo com comida e água. Cai com fracassos e quando você deixa alguém para trás. Ajuda ou atrapalha um pouco em todas as missões, mas nunca deixa ninguém invencível.';

const ESTATISTICAS = [
  { chave: 'missoes', rotulo: 'Missões feitas' },
  { chave: 'sucessos', rotulo: 'Sucessos' },
  { chave: 'falhas', rotulo: 'Falhas' },
  { chave: 'sobreviventes_salvos', rotulo: 'Sobreviventes salvos' },
  { chave: 'zumbis_abatidos', rotulo: 'Zumbis abatidos' },
] as const;

const SLOTS = [
  { rotulo: 'Arma principal', icone: Crosshair },
  { rotulo: 'Corpo a corpo', icone: Swords },
];

export function TelaPersonagem() {
  const { estado } = useEstadoJogo();
  const moral = faixaMoral(estado.moral);

  return (
    <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.2fr)]">
      <div className="space-y-4">
        {/* Nível e XP */}
        <Cartao
          titulo={estado.nome}
          subtitulo="Sobrevivente"
          icone={<Star className="h-6 w-6 text-acento-roxo" aria-hidden />}
          acao={estado.pontos_disponiveis > 0 ? <Selo tom="ambar">{estado.pontos_disponiveis} ponto(s)</Selo> : undefined}
          variante="fita"
        >
          <div className="flex items-end justify-between">
            <p className="text-sm text-texto-suave">Nível</p>
            <p className="font-titulo text-4xl leading-none">{estado.nivel}</p>
          </div>
          <Barra valor={estado.xp} max={estado.xp_proximo} tom="roxo" rotulo="Experiência" ocultarRotulo className="mt-2" />
          <p className="mt-1.5 text-xs text-texto-suave">
            <ContadorRolante valor={estado.xp} className="text-texto" /> / {estado.xp_proximo.toLocaleString('pt-BR')} XP ·
            faltam <span className="font-mono text-texto">{(estado.xp_proximo - estado.xp).toLocaleString('pt-BR')}</span> para o
            nível {estado.nivel + 1}
          </p>
        </Cartao>

        {/* Stamina */}
        <Cartao indice={1}>
          <BarraStamina />
        </Cartao>

        {/* Moral (separada: não recebe pontos) */}
        <Cartao indice={1}>
          <div className="mb-1.5 flex items-center justify-between text-sm">
            <span className="flex items-center gap-2">
              <HeartPulse className="h-4 w-4 text-acento-vermelho" aria-hidden />
              Moral
              <Tooltip conteudo={EXPLICACAO_MORAL}>
                <button
                  type="button"
                  aria-label="O que é moral?"
                  className="flex h-7 w-7 items-center justify-center rounded text-texto-suave hover:text-texto focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde"
                >
                  <Info className="h-4 w-4" aria-hidden />
                </button>
              </Tooltip>
            </span>
            <span className="font-mono">{estado.moral}</span>
          </div>
          <Barra valor={estado.moral} max={100} tom="moral" rotulo="Moral" ocultarRotulo />
          <p className="mt-1.5 text-xs text-texto-suave">
            <span className="text-texto">{moral.rotulo}.</span> {moral.efeito}
          </p>
        </Cartao>

        {/* Equipamento: só 2 slots de arma no MVP */}
        <Cartao titulo="Equipamento" indice={3}>
          <ul className="grid grid-cols-2 gap-2">
            {SLOTS.map(({ rotulo, icone: Icone }) => (
              <li key={rotulo} className="flex flex-col items-center gap-1 rounded-md border border-dashed border-borda px-2 py-4 text-center">
                <Icone className="h-6 w-6 text-texto-suave" aria-hidden />
                <span className="text-xs text-texto-suave">{rotulo}</span>
                <span className="text-sm">Vazio</span>
              </li>
            ))}
          </ul>
          <p className="mt-2 text-xs text-texto-suave">Equipar armas chega na Fase 6, junto com o inventário.</p>
        </Cartao>
      </div>

      <div className="space-y-4">
        <PainelAtributos />

        <Cartao titulo="Histórico" indice={4}>
          <dl className="grid grid-cols-2 gap-3 sm:grid-cols-3">
            {ESTATISTICAS.map(({ chave, rotulo }) => (
              <div key={chave} className="rounded-md border border-borda bg-fundo-0/40 px-3 py-2">
                <dt className="text-xs text-texto-suave">{rotulo}</dt>
                <dd className="text-xl">
                  <ContadorRolante valor={estado.stats[chave]} />
                </dd>
              </div>
            ))}
          </dl>
        </Cartao>
      </div>
    </div>
  );
}
