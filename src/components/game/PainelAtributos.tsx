'use client';

// src/components/game/PainelAtributos.tsx
// Seis atributos com "+" quando há pontos. Os pontos só valem ao clicar em "Confirmar pontos"
// (dá para tirar e desfazer antes). Quem aplica e confere é o servidor.

import { useState } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { ChevronDown, Minus, Plus, RotateCcw } from 'lucide-react';
import { Botao } from '@/components/ui/Botao';
import { Cartao } from '@/components/ui/Cartao';
import { Selo } from '@/components/ui/Selo';
import { useToast } from '@/components/ui/Toast';
import { pedirAcao } from '@/lib/api/cliente';
import { ATRIBUTOS, atributosZerados, somaAtributos, type Atributos, type ChaveAtributo } from '@/lib/game/atributos';
import { faixaMoral } from '@/lib/game/formulas';
import type { EstadoPersonagem } from '@/lib/game/personagem';
import { cn } from '@/lib/utils';
import { useEstadoJogo } from './EstadoJogo';
import { IconeAtributo } from './IconeAtributo';

// Bônus de abrigo e de equipamento chegam nas Fases 6 e 7. Por enquanto, zero.
const BONUS_ABRIGO: Atributos = atributosZerados();
const BONUS_EQUIPAMENTO: Atributos = atributosZerados();

export function PainelAtributos() {
  const { estado, aplicarEstado } = useEstadoJogo();
  const toast = useToast();
  const [extra, setExtra] = useState<Atributos>(atributosZerados);
  const [enviando, setEnviando] = useState(false);
  const [detalhe, setDetalhe] = useState(false);

  const pontos = estado.pontos_disponiveis;
  const usados = somaAtributos(extra);
  const restantes = pontos - usados;
  const max = estado.atributo_maximo;
  const moral = faixaMoral(estado.moral);

  function mudar(chave: ChaveAtributo, delta: number) {
    setExtra((e) => ({ ...e, [chave]: Math.max(0, e[chave] + delta) }));
  }

  async function confirmar() {
    setEnviando(true);
    const r = await pedirAcao<{ estado: EstadoPersonagem | null }>('/api/personagem/pontos', extra);
    setEnviando(false);
    if (!r.ok) {
      toast.erro('Não deu certo', r.erro);
      return;
    }
    aplicarEstado(r.dados.estado);
    setExtra(atributosZerados());
    toast.sucesso('Pontos aplicados', `${usados} ponto(s) distribuído(s).`);
  }

  return (
    <Cartao
      titulo="Atributos"
      subtitulo={`Máximo ${max} em cada. Só sobem com pontos de nível.`}
      acao={pontos > 0 ? <Selo tom="ambar">{restantes} ponto(s) livre(s)</Selo> : undefined}
      indice={2}
    >
      <ul className="space-y-2">
        {ATRIBUTOS.map((a) => {
          const base = estado.atributos[a.chave];
          const somado = extra[a.chave];
          const podeSomar = restantes > 0 && base + somado < max;
          return (
            <li key={a.chave} className="flex items-center gap-3 rounded-md border border-borda bg-fundo-0/40 px-3 py-2">
              <IconeAtributo chave={a.chave} />
              <div className="min-w-0 flex-1">
                <p className="text-sm font-medium">{a.nome}</p>
                <p className="truncate text-xs text-texto-suave" title={a.usos}>
                  {a.curta}
                </p>
              </div>
              <div className="flex items-center gap-1">
                {somado > 0 && (
                  <button
                    type="button"
                    onClick={() => mudar(a.chave, -1)}
                    aria-label={`Tirar 1 ponto de ${a.nome}`}
                    className="flex h-9 w-9 items-center justify-center rounded-md border border-borda text-texto-suave hover:bg-fundo-2 hover:text-texto focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde"
                  >
                    <Minus className="h-4 w-4" aria-hidden />
                  </button>
                )}
                <span className="w-14 text-right font-mono text-lg" aria-label={`${a.nome}: ${base + somado}`}>
                  {base + somado}
                  <AnimatePresence>
                    {somado > 0 && (
                      <motion.span
                        initial={{ opacity: 0, y: -4 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0 }}
                        className="ml-1 text-xs text-acento-verde"
                      >
                        +{somado}
                      </motion.span>
                    )}
                  </AnimatePresence>
                </span>
                {pontos > 0 && (
                  <button
                    type="button"
                    onClick={() => podeSomar && mudar(a.chave, 1)}
                    aria-disabled={!podeSomar || undefined}
                    aria-label={`Somar 1 ponto em ${a.nome}`}
                    title={base + somado >= max ? `Máximo ${max}` : restantes <= 0 ? 'Sem pontos livres' : undefined}
                    className={cn(
                      'flex h-9 w-9 items-center justify-center rounded-md border focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde',
                      podeSomar
                        ? 'border-acento-verde bg-acento-verde/15 text-acento-verde hover:bg-acento-verde/30'
                        : 'cursor-not-allowed border-borda text-texto-suave opacity-40',
                    )}
                  >
                    <Plus className="h-4 w-4" aria-hidden />
                  </button>
                )}
              </div>
            </li>
          );
        })}
      </ul>

      {pontos > 0 && (
        <div className="mt-4 flex flex-wrap items-center justify-end gap-2">
          <Botao
            variante="fantasma"
            onClick={() => setExtra(atributosZerados())}
            motivoDesabilitado={usados === 0 ? 'Nada para desfazer' : undefined}
            icone={<RotateCcw className="h-4 w-4" aria-hidden />}
          >
            Desfazer
          </Botao>
          <Botao
            onClick={confirmar}
            carregando={enviando}
            motivoDesabilitado={usados === 0 ? 'Use o "+" para escolher onde colocar os pontos' : undefined}
          >
            Confirmar pontos
          </Botao>
        </div>
      )}

      {/* Detalhe dos bônus */}
      <button
        type="button"
        onClick={() => setDetalhe((d) => !d)}
        aria-expanded={detalhe}
        aria-controls="detalhe-bonus"
        className="mt-4 flex min-h-[44px] w-full items-center justify-between rounded-md px-1 text-sm text-texto-suave hover:text-texto focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde"
      >
        Ver bônus totais
        <ChevronDown className={cn('h-4 w-4 transition-transform', detalhe && 'rotate-180')} aria-hidden />
      </button>
      <AnimatePresence initial={false}>
        {detalhe && (
          <motion.div
            id="detalhe-bonus"
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            className="overflow-hidden"
          >
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="text-left text-xs text-texto-suave">
                    <th className="py-1 font-normal">Atributo</th>
                    <th className="py-1 text-right font-normal">Base</th>
                    <th className="py-1 text-right font-normal">Abrigo</th>
                    <th className="py-1 text-right font-normal">Equip.</th>
                    <th className="py-1 text-right font-normal">Total</th>
                  </tr>
                </thead>
                <tbody>
                  {ATRIBUTOS.map((a) => {
                    const base = estado.atributos[a.chave];
                    const total = base + BONUS_ABRIGO[a.chave] + BONUS_EQUIPAMENTO[a.chave];
                    return (
                      <tr key={a.chave} className="border-t border-borda">
                        <td className="py-1.5">{a.nome}</td>
                        <td className="py-1.5 text-right font-mono">{base}</td>
                        <td className="py-1.5 text-right font-mono text-texto-suave">+{BONUS_ABRIGO[a.chave]}</td>
                        <td className="py-1.5 text-right font-mono text-texto-suave">+{BONUS_EQUIPAMENTO[a.chave]}</td>
                        <td className="py-1.5 text-right font-mono">{total}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
            <p className="mt-2 text-xs text-texto-suave">
              Moral ({moral.rotulo.toLowerCase()}): {moral.efeito} Vale para todas as missões, não para um atributo só.
            </p>
            <p className="mt-1 text-xs text-texto-suave">Bônus de abrigo e de equipamento passam a contar nas próximas fases.</p>
          </motion.div>
        )}
      </AnimatePresence>
    </Cartao>
  );
}
