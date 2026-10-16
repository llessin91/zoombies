'use client';

// src/components/game/ModalPreparacao.tsx
// Preparação da missão: história, atributos que pesam, arma e consumíveis opcionais,
// carga e o botão "Iniciar expedição". As expedições em si chegam na Fase 5.

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { AlertTriangle, Backpack, Flame, MapPin, UserPlus, Volume2 } from 'lucide-react';
import { Barra } from '@/components/ui/Barra';
import { Botao } from '@/components/ui/Botao';
import { Modal } from '@/components/ui/Modal';
import { Selo, SeloDificuldade } from '@/components/ui/Selo';
import { ATRIBUTOS, type ChaveAtributo } from '@/lib/game/atributos';
import { CATEGORIAS, formatarSegundos } from '@/lib/game/missoes';
import type { ItemCatalogo, ItemMochila, MissaoMundo } from '@/lib/game/mundo';
import { textoEsgotado, SeloFaixa } from './CartaoMissao';
import { useEstadoJogo, useStaminaProjetada } from './EstadoJogo';
import { useToast } from '@/components/ui/Toast';
import { pedirAcao } from '@/lib/api/cliente';
import { IconeAtributo } from './IconeAtributo';
import { IconeItem } from './IconeItem';

const RISCOS: Record<string, { rotulo: string; icone: typeof Flame }> = {
  vazamento: { rotulo: 'Vazamento: pode perder parte do que coletar', icone: AlertTriangle },
  incendio: { rotulo: 'Incêndio: pode sair ferido', icone: Flame },
  explosao: { rotulo: 'Explosão: o local pode ir pelos ares', icone: Flame },
};

interface Props {
  missao: MissaoMundo | null;
  nomeLocal: string;
  diasEsgotado: number | null;
  itens: Record<string, ItemCatalogo>;
  mochila: ItemMochila[];
  cargaMaxima: number;
  aoFechar: () => void;
}

export function ModalPreparacao({ missao: m, nomeLocal, diasEsgotado, itens, mochila, cargaMaxima, aoFechar }: Props) {
  const stamina = useStaminaProjetada();
  const { estado } = useEstadoJogo();
  const router = useRouter();
  const toast = useToast();
  const [enviando, setEnviando] = useState(false);
  // Começa com a arma equipada (principal; senão a de corpo a corpo), se ela estiver na mochila
  const [arma, setArma] = useState(() => {
    const eq = estado.equipamento.arma_principal ?? estado.equipamento.arma_corpo_a_corpo;
    return eq && mochila.some((i) => i.id === eq.inventory_id && (i.durabilidade ?? 0) > 0) ? eq.inventory_id : '';
  });
  const [consumiveis, setConsumiveis] = useState<string[]>([]);

  const armas = mochila.filter((i) => i.tipo === 'arma' && i.local === 'mochila');
  // Consumíveis da mochila e do depósito, somados por tipo de item
  const usaveis = Object.values(
    mochila
      .filter((i) => i.tipo === 'consumivel')
      .reduce<Record<string, ItemMochila>>((acc, i) => {
        acc[i.slug] = acc[i.slug] ? { ...acc[i.slug], quantidade: acc[i.slug].quantidade + i.quantidade } : { ...i };
        return acc;
      }, {}),
  );
  const pesoLevado =
    (armas.find((a) => a.id === arma)?.peso ?? 0) + usaveis.filter((c) => consumiveis.includes(c.slug)).reduce((s, c) => s + c.peso, 0);

  if (!m) {
    return (
      <Modal aberto={false} aoFechar={aoFechar} titulo="">
        {null}
      </Modal>
    );
  }

  const pesos = Object.entries(m.pesos)
    .filter(([, p]) => p > 0)
    .sort((a, b) => b[1] - a[1]) as [ChaveAtributo, number][];
  const categoria = CATEGORIAS.find((c) => c.valor === m.categoria)?.rotulo ?? m.categoria;

  // Motivo do botão desabilitado, na ordem de importância
  let motivo: string | undefined;
  if (m.estado === 'bloqueada') motivo = m.motivo ?? 'Missão bloqueada';
  else if (m.estado === 'esgotada') motivo = textoEsgotado(diasEsgotado);
  else if (stamina.atual < m.custoStamina) motivo = `Stamina insuficiente (precisa de ${m.custoStamina})`;
  else if (estado.expedicao) motivo = estado.expedicao.loot_pendente ? 'Decida o que levar da última expedição' : 'Você já está numa expedição';
  else if (pesoLevado > cargaMaxima) motivo = 'Peso demais para levar';
  else motivo = undefined;

  async function iniciar() {
    if (!m) return;
    setEnviando(true);
    const r = await pedirAcao<{ id: string }>('/api/expedicao/iniciar', {
      missao: m.slug,
      arma: arma || null,
      consumiveis: consumiveis.map((item) => ({ item, qtd: 1 })),
    });
    if (!r.ok) {
      setEnviando(false);
      toast.erro('Não deu para sair', r.erro);
      return;
    }
    router.push(`/expedicao/${r.dados.id}`);
  }

  return (
    <Modal aberto={Boolean(m)} aoFechar={aoFechar} titulo={m.nome} largura="lg">
      <div className="space-y-5">
        <div className="flex flex-wrap items-center gap-1.5">
          <SeloDificuldade nivel={m.dificuldade} />
          <Selo>{categoria}</Selo>
          <Selo icone={<MapPin className="h-3 w-3" aria-hidden />}>
            {nomeLocal}
            {m.ponto && ` · ${m.ponto}`}
          </Selo>
          <Selo>{formatarSegundos(m.duracaoSegundos)}</Selo>
          <Selo tom="roxo">{m.xp} XP</Selo>
          {m.estado === 'disponivel' && <SeloFaixa faixa={m.faixa} />}
        </div>

        <p className="border-l-2 border-acento-ambar/60 pl-3 text-sm italic text-texto">{m.abertura}</p>

        {/* Atributos que pesam nesta missão */}
        <section aria-labelledby="titulo-pesos">
          <h3 id="titulo-pesos" className="mb-2 text-sm font-medium">
            O que conta aqui
          </h3>
          <ul className="space-y-2">
            {pesos.map(([chave, peso]) => {
              const info = ATRIBUTOS.find((a) => a.chave === chave);
              return (
                <li key={chave} className="flex items-center gap-3">
                  <IconeAtributo chave={chave} className="h-5 w-5" />
                  <span className="w-24 text-sm">{info?.nome ?? chave}</span>
                  <Barra valor={peso} max={100} tom="azul" altura="sm" rotulo={`Peso de ${info?.nome ?? chave}`} ocultarRotulo />
                </li>
              );
            })}
          </ul>
        </section>

        {/* Recompensas possíveis e riscos */}
        <section aria-labelledby="titulo-recompensas" className="grid gap-4 sm:grid-cols-2">
          <div>
            <h3 id="titulo-recompensas" className="mb-2 text-sm font-medium">
              Pode render
            </h3>
            <ul className="space-y-1">
              {m.loot.map((l, i) => (
                <li key={`${l.item}-${i}`} className="flex items-center gap-2 text-sm">
                  <IconeItem slug={l.item} tipo={itens[l.item]?.tipo} />
                  {itens[l.item]?.nome ?? l.item}
                  {l.alta_qualidade && <Selo tom="ambar">alta qualidade</Selo>}
                </li>
              ))}
            </ul>
          </div>
          {Boolean(m.especial.riscos?.length || m.especial.ruido || m.especial.recruta_chance) && (
            <div>
              <h3 className="mb-2 text-sm font-medium">Fique atento</h3>
              <ul className="space-y-1 text-sm text-texto-suave">
                {m.especial.riscos?.map((r) => {
                  const info = RISCOS[r];
                  if (!info) return null;
                  const Icone = info.icone;
                  return (
                    <li key={r} className="flex items-start gap-2">
                      <Icone className="mt-0.5 h-4 w-4 shrink-0 text-acento-laranja" aria-hidden />
                      {info.rotulo}
                    </li>
                  );
                })}
                {Boolean(m.especial.ruido) && (
                  <li className="flex items-start gap-2">
                    <Volume2 className="mt-0.5 h-4 w-4 shrink-0 text-acento-ambar" aria-hidden />
                    Barulhento: atrai encontros hostis (Agilidade ajuda a passar despercebido)
                  </li>
                )}
                {Boolean(m.especial.recruta_chance) && (
                  <li className="flex items-start gap-2">
                    <UserPlus className="mt-0.5 h-4 w-4 shrink-0 text-acento-verde" aria-hidden />
                    Pode trazer alguém para o abrigo
                  </li>
                )}
              </ul>
            </div>
          )}
        </section>

        {/* Arma e consumíveis */}
        <section className="grid gap-4 sm:grid-cols-2">
          <div>
            <label htmlFor="escolha-arma" className="mb-1 block text-sm font-medium">
              Arma (opcional)
            </label>
            <select
              id="escolha-arma"
              value={arma}
              onChange={(e) => setArma(e.target.value)}
              disabled={armas.length === 0}
              className="min-h-[44px] w-full rounded-md border border-borda bg-fundo-0 px-3 text-sm disabled:opacity-60"
            >
              <option value="">{armas.length === 0 ? 'Nenhuma arma na mochila' : 'Sem arma'}</option>
              {armas.map((a, i) => (
                <option key={`${a.id}-${i}`} value={a.id}>
                  {a.nome}
                  {a.durabilidade !== null ? ` (durabilidade ${a.durabilidade})` : ''}
                </option>
              ))}
            </select>
          </div>
          <fieldset>
            <legend className="mb-1 text-sm font-medium">Consumíveis (opcional)</legend>
            {usaveis.length === 0 ? (
              <p className="text-sm text-texto-suave">Nada na mochila nem no depósito. Bandagens e molotovs aparecem aqui.</p>
            ) : (
              <ul className="space-y-1">
                {usaveis.map((c) => (
                  <li key={c.slug}>
                    <label className="flex min-h-[36px] items-center gap-2 text-sm">
                      <input
                        type="checkbox"
                        checked={consumiveis.includes(c.slug)}
                        onChange={(e) =>
                          setConsumiveis((lista) => (e.target.checked ? [...lista, c.slug] : lista.filter((s) => s !== c.slug)))
                        }
                        className="h-4 w-4 accent-[rgb(var(--acento-verde))]"
                      />
                      <IconeItem slug={c.slug} tipo={c.tipo} />
                      {c.nome} <span className="text-texto-suave">×{c.quantidade}</span>
                    </label>
                  </li>
                ))}
              </ul>
            )}
          </fieldset>
        </section>

        {/* Carga */}
        <section>
          <div className="mb-1 flex items-center justify-between text-sm">
            <span className="flex items-center gap-2">
              <Backpack className="h-4 w-4 text-texto-suave" aria-hidden />
              Carga levada
            </span>
            <span className="font-mono">
              {pesoLevado} / {cargaMaxima}
            </span>
          </div>
          <Barra valor={pesoLevado} max={cargaMaxima} tom="verde" rotulo="Carga levada" ocultarRotulo />
          <p className="mt-1 text-xs text-texto-suave">O que passar da capacidade na volta você escolhe o que deixar para trás.</p>
        </section>

        <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          <Botao variante="secundario" onClick={aoFechar}>
            Voltar
          </Botao>
          <Botao variante="acao" custoStamina={m.custoStamina} motivoDesabilitado={motivo} carregando={enviando} onClick={iniciar}>
            Iniciar expedição
          </Botao>
        </div>
      </div>
    </Modal>
  );
}
