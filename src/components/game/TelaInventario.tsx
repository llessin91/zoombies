'use client';

// src/components/game/TelaInventario.tsx
// Inventário: filtros e busca, grade de itens com brilho por raridade (e brilho extra nos novos),
// detalhe com Usar / Equipar / Descartar, slots de arma e barras de carga e depósito.
// Toda ação vai para o servidor; a tela só mostra a resposta.

import { useEffect, useMemo, useState } from 'react';
import { motion, useReducedMotion } from 'framer-motion';
import { Backpack, Crosshair, Search, Sparkles, Swords, Trash2, Warehouse } from 'lucide-react';
import { Barra } from '@/components/ui/Barra';
import { Botao } from '@/components/ui/Botao';
import { Cartao } from '@/components/ui/Cartao';
import { EstadoVazio } from '@/components/ui/Estados';
import { Modal } from '@/components/ui/Modal';
import { Selo, SeloRaridade } from '@/components/ui/Selo';
import { useToast } from '@/components/ui/Toast';
import { pedirAcao } from '@/lib/api/cliente';
import {
  FILTROS,
  NOME_SLOT,
  filtrarItens,
  motivoNaoDescartar,
  motivoNaoEquipar,
  slotDaArma,
  type EstadoInventario,
  type FiltroInventario,
  type ItemInventario,
  type Slot,
} from '@/lib/game/inventario';
import { cn } from '@/lib/utils';
import { useEstadoJogo } from './EstadoJogo';
import { BORDA_RARIDADE, BRILHO_RARIDADE, IconeItem } from './IconeItem';

const TIPO_ROTULO: Record<string, string> = { recurso: 'Recurso', consumivel: 'Consumível', arma: 'Arma', item_chave: 'Item-chave' };
const SUBTIPO_ROTULO: Record<string, string> = {
  pistola: 'Pistola',
  fuzil: 'Fuzil',
  escopeta: 'Escopeta',
  rifle_precisao: 'Rifle de precisão',
  corpo_a_corpo: 'Corpo a corpo',
};

type RespostaAcao = { mensagem: string; inventario: EstadoInventario };

function formatarPeso(p: number) {
  return p.toLocaleString('pt-BR', { maximumFractionDigits: 1 });
}

function efeitos(i: ItemInventario): string[] {
  const lista: string[] = [];
  if (i.recupera_stamina) lista.push(`Recupera ${i.recupera_stamina} de stamina (sem passar do máximo)`);
  if (i.cura_ferimento) lista.push(`Cura ${i.cura_ferimento} nível(is) de ferimento`);
  const bonus = Number((i.efeitos as Record<string, unknown>).bonus_missao ?? 0);
  if (bonus) lista.push(`Bônus em missões: +${bonus}${i.tipo === 'consumivel' ? ' (gasto na expedição)' : ''}`);
  if (i.tipo === 'arma') lista.push(`Vai no slot: ${NOME_SLOT[slotDaArma(i.subtipo)]}`);
  return lista;
}

export function TelaInventario({ inicial }: { inicial: EstadoInventario }) {
  const { estado: personagem, sincronizar } = useEstadoJogo();
  const toast = useToast();
  const reduzir = useReducedMotion();
  const [inv, setInv] = useState(inicial);
  const [filtro, setFiltro] = useState<FiltroInventario>('todos');
  const [busca, setBusca] = useState('');
  const [aberto, setAberto] = useState<string | null>(null);
  const [descartando, setDescartando] = useState(false);
  const [qtdDescarte, setQtdDescarte] = useState(1);
  const [enviando, setEnviando] = useState<string | null>(null);
  // "Novo" fica marcado nesta visita, mesmo depois de avisar o servidor que você viu
  const [novos] = useState(() => new Set(inicial.itens.filter((i) => i.novo).map((i) => i.id)));

  useEffect(() => {
    if (inicial.itens.some((i) => i.novo)) {
      void pedirAcao('/api/inventario/visto').then(() => sincronizar());
    }
  }, [inicial.itens, sincronizar]);

  const visiveis = useMemo(() => filtrarItens(inv.itens, filtro, busca), [inv.itens, filtro, busca]);
  const item = inv.itens.find((i) => i.id === aberto) ?? null;
  const equipados = (['arma_principal', 'arma_corpo_a_corpo'] as Slot[]).map((slot) => ({
    slot,
    item: inv.itens.find((i) => i.equipado === slot) ?? null,
  }));

  async function agir(nome: string, caminho: string, corpo: unknown, fechar = false) {
    setEnviando(nome);
    const r = await pedirAcao<RespostaAcao>(caminho, corpo);
    setEnviando(null);
    if (!r.ok) {
      toast.erro('Não deu certo', r.erro);
      return;
    }
    setInv(r.dados.inventario);
    toast.sucesso(r.dados.mensagem);
    void sincronizar(); // stamina, ferimentos e equipamento no resto do jogo
    if (fechar) {
      setDescartando(false);
      if (!r.dados.inventario.itens.some((i) => i.id === aberto)) setAberto(null);
    }
  }

  const acimaDaCarga = inv.peso_mochila > inv.carga_max;

  return (
    <div className="space-y-4">
      {/* Carga e depósito */}
      <div className="grid gap-3 md:grid-cols-2">
        <Cartao>
          <div className="mb-1.5 flex items-center justify-between text-sm">
            <span className="flex items-center gap-2">
              <Backpack className="h-4 w-4 text-texto-suave" aria-hidden />
              Mochila
            </span>
            <span className={cn('font-mono', acimaDaCarga && 'text-acento-ambar')}>
              {formatarPeso(inv.peso_mochila)} / {formatarPeso(inv.carga_max)}
            </span>
          </div>
          <Barra valor={inv.peso_mochila} max={inv.carga_max} tom={acimaDaCarga ? 'ambar' : 'verde'} rotulo="Peso na mochila" ocultarRotulo />
          <p className="mt-1.5 text-xs text-texto-suave">
            {acimaDaCarga
              ? 'Mais do que você carrega numa expedição. Quando tiver abrigo, guarde o excesso no depósito.'
              : 'Capacidade de carga em expedição: 10 + Força × 2.'}
          </p>
        </Cartao>
        <Cartao>
          <div className="mb-1.5 flex items-center justify-between text-sm">
            <span className="flex items-center gap-2">
              <Warehouse className="h-4 w-4 text-texto-suave" aria-hidden />
              Depósito do abrigo
            </span>
            <span className="font-mono">
              {inv.deposito.tem_abrigo ? `${formatarPeso(inv.deposito.usado)} / ${formatarPeso(inv.deposito.capacidade)}` : '—'}
            </span>
          </div>
          <Barra valor={inv.deposito.usado} max={inv.deposito.capacidade} tom="azul" rotulo="Uso do depósito" ocultarRotulo />
          <p className="mt-1.5 text-xs text-texto-suave">
            {inv.deposito.tem_abrigo ? 'O que fica guardado no abrigo.' : 'Você ainda não tem abrigo. Depósito chega com o abrigo (Fase 7).'}
          </p>
        </Cartao>
      </div>

      {/* Slots de arma */}
      <Cartao titulo="Equipado">
        <ul className="grid gap-2 sm:grid-cols-2">
          {equipados.map(({ slot, item: eq }) => {
            const Icone = slot === 'arma_principal' ? Crosshair : Swords;
            return (
              <li key={slot} className={cn('flex items-center gap-3 rounded-md border px-3 py-2', eq ? BORDA_RARIDADE[eq.raridade] : 'border-dashed border-borda')}>
                <Icone className="h-5 w-5 text-texto-suave" aria-hidden />
                <div className="min-w-0 flex-1">
                  <p className="text-xs text-texto-suave">{NOME_SLOT[slot]}</p>
                  <p className="truncate text-sm">{eq ? eq.nome : 'Vazio'}</p>
                  {eq?.durabilidade !== null && eq?.durabilidade_max ? (
                    <Barra valor={eq.durabilidade} max={eq.durabilidade_max} tom="laranja" altura="sm" rotulo={`Durabilidade de ${eq.nome}`} ocultarRotulo className="mt-1" />
                  ) : null}
                </div>
                {eq && (
                  <Botao variante="fantasma" carregando={enviando === `des-${slot}`} onClick={() => agir(`des-${slot}`, '/api/inventario/desequipar', { slot })}>
                    Tirar
                  </Botao>
                )}
              </li>
            );
          })}
        </ul>
        <p className="mt-2 text-xs text-texto-suave">A arma equipada já vem escolhida na preparação da missão.</p>
      </Cartao>

      {/* Filtros e busca */}
      <div className="flex flex-col gap-3 lg:flex-row lg:items-center">
        <div role="tablist" aria-label="Tipo de item" className="flex flex-wrap gap-1.5">
          {FILTROS.map((f) => {
            const qtd = filtrarItens(inv.itens, f.valor, '').length;
            return (
              <button
                key={f.valor}
                role="tab"
                type="button"
                aria-selected={filtro === f.valor}
                onClick={() => setFiltro(f.valor)}
                className={cn(
                  'min-h-[40px] rounded-md border px-3 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde',
                  filtro === f.valor ? 'border-acento-verde bg-acento-verde/15' : 'border-borda hover:bg-fundo-2',
                )}
              >
                {f.rotulo} <span className="font-mono text-xs text-texto-suave">{qtd}</span>
              </button>
            );
          })}
        </div>
        <label className="relative lg:ml-auto lg:w-72">
          <span className="sr-only">Buscar item</span>
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-texto-suave" aria-hidden />
          <input
            type="search"
            value={busca}
            onChange={(e) => setBusca(e.target.value)}
            placeholder="Buscar item"
            className="min-h-[44px] w-full rounded-md border border-borda bg-fundo-1 pl-9 pr-3 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde"
          />
        </label>
      </div>

      {/* Grade */}
      {inv.itens.length === 0 ? (
        <Cartao>
          <EstadoVazio texto="Mochila vazia. Até as moscas desistiram." detalhe="Saia em missões para trazer coisas." />
        </Cartao>
      ) : visiveis.length === 0 ? (
        <Cartao>
          <EstadoVazio texto="Nada com esse filtro." detalhe={busca ? 'Tente outra palavra.' : undefined} />
        </Cartao>
      ) : (
        <ul className="grid grid-cols-2 gap-2 sm:grid-cols-3 lg:grid-cols-4 2xl:grid-cols-6">
          {visiveis.map((i, k) => {
            const novo = novos.has(i.id);
            return (
              <motion.li key={i.id} initial={reduzir ? false : { opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: Math.min(k, 12) * 0.03 }}>
                <button
                  type="button"
                  onClick={() => {
                    setAberto(i.id);
                    setDescartando(false);
                    setQtdDescarte(1);
                  }}
                  className={cn(
                    'relative flex h-full w-full flex-col items-center gap-1.5 rounded-lg border bg-fundo-1 p-3 text-center transition-transform hover:-translate-y-0.5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde',
                    BORDA_RARIDADE[i.raridade],
                    novo && BRILHO_RARIDADE[i.raridade === 'comum' ? 'incomum' : i.raridade],
                  )}
                >
                  {novo && (
                    <span className="absolute right-1.5 top-1.5 flex items-center gap-0.5 rounded bg-acento-verde/20 px-1.5 text-[10px] text-acento-verde">
                      <Sparkles className="h-3 w-3" aria-hidden /> novo
                    </span>
                  )}
                  {i.equipado && <span className="absolute left-1.5 top-1.5 rounded bg-acento-laranja/20 px-1.5 text-[10px] text-acento-laranja">equipada</span>}
                  <span className={cn('mt-3 flex h-11 w-11 items-center justify-center rounded-md bg-fundo-2', novo && !reduzir && 'animate-pulse')}>
                    <IconeItem slug={i.slug} tipo={i.tipo} className="h-6 w-6" />
                  </span>
                  <span className="line-clamp-2 text-sm leading-tight">{i.nome}</span>
                  {i.tipo === 'arma' && i.durabilidade !== null && i.durabilidade_max ? (
                    <Barra valor={i.durabilidade} max={i.durabilidade_max} tom={i.durabilidade > 0 ? 'laranja' : 'vermelho'} altura="sm" rotulo={`Durabilidade de ${i.nome}`} ocultarRotulo />
                  ) : (
                    <span className="font-mono text-xs text-texto-suave">×{i.quantidade}</span>
                  )}
                </button>
              </motion.li>
            );
          })}
        </ul>
      )}

      {/* Detalhe */}
      <Modal aberto={Boolean(item)} aoFechar={() => setAberto(null)} titulo={item?.nome ?? ''}>
        {item && (
          <div className="space-y-4">
            <div className="flex items-start gap-3">
              <span className={cn('flex h-14 w-14 shrink-0 items-center justify-center rounded-lg border bg-fundo-2', BORDA_RARIDADE[item.raridade], BRILHO_RARIDADE[item.raridade])}>
                <IconeItem slug={item.slug} tipo={item.tipo} className="h-8 w-8" />
              </span>
              <div className="space-y-1.5">
                <div className="flex flex-wrap gap-1.5">
                  <SeloRaridade nivel={item.raridade} />
                  <Selo>{item.subtipo ? SUBTIPO_ROTULO[item.subtipo] ?? TIPO_ROTULO[item.tipo] : TIPO_ROTULO[item.tipo]}</Selo>
                  {item.equipado && <Selo tom="laranja">Equipada</Selo>}
                </div>
                <p className="text-sm text-texto-suave">{item.descricao}</p>
              </div>
            </div>

            <dl className="grid grid-cols-2 gap-2 text-sm">
              <div className="rounded-md border border-borda px-3 py-2">
                <dt className="text-xs text-texto-suave">Quantidade</dt>
                <dd className="font-mono">{item.quantidade}</dd>
              </div>
              <div className="rounded-md border border-borda px-3 py-2">
                <dt className="text-xs text-texto-suave">Peso</dt>
                <dd className="font-mono">
                  {formatarPeso(item.peso)} cada · {formatarPeso(item.peso * item.quantidade)}
                </dd>
              </div>
              {item.tipo === 'arma' && (
                <>
                  <div className="rounded-md border border-borda px-3 py-2">
                    <dt className="text-xs text-texto-suave">Durabilidade</dt>
                    <dd className="font-mono">
                      {item.durabilidade ?? 0} / {item.durabilidade_max ?? 0}
                    </dd>
                  </div>
                  <div className="rounded-md border border-borda px-3 py-2">
                    <dt className="text-xs text-texto-suave">Nível exigido</dt>
                    <dd className={cn('font-mono', item.nivel_requisito > personagem.nivel && 'text-acento-vermelho')}>{item.nivel_requisito}</dd>
                  </div>
                </>
              )}
            </dl>

            {efeitos(item).length > 0 && (
              <ul className="space-y-1 text-sm">
                {efeitos(item).map((e) => (
                  <li key={e} className="flex items-start gap-2">
                    <span aria-hidden className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-acento-verde" />
                    {e}
                  </li>
                ))}
              </ul>
            )}

            {!descartando ? (
              <div className="flex flex-wrap justify-end gap-2">
                {item.tipo !== 'arma' && (
                  <Botao
                    onClick={() => agir('usar', '/api/inventario/usar', { id: item.id })}
                    carregando={enviando === 'usar'}
                    motivoDesabilitado={item.motivo_nao_usar ?? undefined}
                  >
                    Usar
                  </Botao>
                )}
                {item.tipo === 'arma' &&
                  (item.equipado ? (
                    <Botao variante="secundario" onClick={() => agir('desequipar', '/api/inventario/desequipar', { slot: item.equipado })} carregando={enviando === 'desequipar'}>
                      Desequipar
                    </Botao>
                  ) : (
                    <Botao
                      onClick={() => agir('equipar', '/api/inventario/equipar', { id: item.id })}
                      carregando={enviando === 'equipar'}
                      motivoDesabilitado={motivoNaoEquipar(item, personagem.nivel) ?? undefined}
                    >
                      Equipar
                    </Botao>
                  ))}
                <Botao
                  variante="perigo"
                  icone={<Trash2 className="h-4 w-4" aria-hidden />}
                  onClick={() => setDescartando(true)}
                  motivoDesabilitado={motivoNaoDescartar(item, 1, item.quantidade) ?? undefined}
                >
                  Descartar
                </Botao>
              </div>
            ) : (
              <div className="space-y-3 rounded-md border border-acento-vermelho/50 bg-acento-vermelho/5 p-3">
                <p className="text-sm">Descartar quantos? Não tem volta.</p>
                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    aria-label="Menos 1"
                    onClick={() => setQtdDescarte((q) => Math.max(1, q - 1))}
                    className="h-10 w-10 rounded-md border border-borda hover:bg-fundo-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde"
                  >
                    −
                  </button>
                  <span className="w-16 text-center font-mono" aria-live="polite">
                    {qtdDescarte} / {item.quantidade}
                  </span>
                  <button
                    type="button"
                    aria-label="Mais 1"
                    onClick={() => setQtdDescarte((q) => Math.min(item.quantidade, q + 1))}
                    className="h-10 w-10 rounded-md border border-borda hover:bg-fundo-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde"
                  >
                    +
                  </button>
                  <button type="button" onClick={() => setQtdDescarte(item.quantidade)} className="text-xs text-texto-suave underline">
                    tudo
                  </button>
                </div>
                <div className="flex justify-end gap-2">
                  <Botao variante="fantasma" onClick={() => setDescartando(false)}>
                    Cancelar
                  </Botao>
                  <Botao
                    variante="perigo"
                    carregando={enviando === 'descartar'}
                    onClick={() => agir('descartar', '/api/inventario/descartar', { id: item.id, qtd: qtdDescarte }, true)}
                  >
                    Descartar {qtdDescarte}
                  </Botao>
                </div>
              </div>
            )}
          </div>
        )}
      </Modal>
    </div>
  );
}
