// src/lib/game/inventario.ts
// Regras e formato do inventário. Espelha a migration 0009 (motivo_nao_usar, slot_da_arma, estado_inventario).
// Quem decide é o banco; aqui ficam filtros e busca da tela, contas de peso e os testes.

import { z } from 'zod';

export type TipoItem = 'recurso' | 'consumivel' | 'arma' | 'item_chave';
export type Slot = 'arma_principal' | 'arma_corpo_a_corpo';
export type FiltroInventario = 'todos' | 'recurso' | 'consumivel' | 'arma' | 'item_chave' | 'outros';

export const FILTROS: { valor: FiltroInventario; rotulo: string }[] = [
  { valor: 'todos', rotulo: 'Todos' },
  { valor: 'recurso', rotulo: 'Recursos' },
  { valor: 'consumivel', rotulo: 'Consumíveis' },
  { valor: 'arma', rotulo: 'Armas' },
  { valor: 'item_chave', rotulo: 'Itens-chave' },
  { valor: 'outros', rotulo: 'Outros' },
];

export const NOME_SLOT: Record<Slot, string> = {
  arma_principal: 'Arma principal',
  arma_corpo_a_corpo: 'Corpo a corpo',
};

/** Corpo a corpo vai no slot próprio; pistolas, fuzis, escopetas e rifles na arma principal */
export function slotDaArma(subtipo: string | null | undefined): Slot {
  return subtipo === 'corpo_a_corpo' ? 'arma_corpo_a_corpo' : 'arma_principal';
}

const n = z.coerce.number();

export const itemInventarioSchema = z.object({
  id: z.string(),
  slug: z.string(),
  nome: z.string(),
  tipo: z.enum(['recurso', 'consumivel', 'arma', 'item_chave']),
  subtipo: z.string().nullable(),
  raridade: z.enum(['comum', 'incomum', 'raro', 'epico', 'lendario']),
  peso: n,
  descricao: z.string(),
  efeitos: z.record(z.unknown()).nullable().transform((e) => e ?? {}),
  quantidade: n,
  durabilidade: n.nullable(),
  durabilidade_max: n.nullable(),
  nivel_requisito: n,
  local: z.enum(['mochila', 'deposito']),
  equipado: z.enum(['arma_principal', 'arma_corpo_a_corpo']).nullable(),
  em_expedicao: z.boolean(),
  novo: z.boolean(),
  motivo_nao_usar: z.string().nullable(),
  recupera_stamina: n.nullable().optional(),
  cura_ferimento: n.nullable().optional(),
});

export const estadoInventarioSchema = z.object({
  itens: z.array(itemInventarioSchema),
  peso_mochila: n,
  carga_max: n,
  deposito: z.object({ tem_abrigo: z.boolean(), capacidade: n, usado: n }),
  visto_em: z.string(),
});

export type ItemInventario = z.infer<typeof itemInventarioSchema>;
export type EstadoInventario = z.infer<typeof estadoInventarioSchema>;

export function lerEstadoInventario(dados: unknown): EstadoInventario {
  return estadoInventarioSchema.parse(dados);
}

/** Tira acentos e deixa minúsculo, para a busca achar "agua" em "Água" */
export function normalizar(texto: string): string {
  return texto.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim();
}

export function filtrarItens<T extends { tipo: string; nome: string; descricao?: string }>(itens: T[], filtro: FiltroInventario, busca: string): T[] {
  const termo = normalizar(busca);
  return itens.filter((i) => {
    const tipoOk = filtro === 'todos' || (filtro === 'outros' ? !['recurso', 'consumivel', 'arma', 'item_chave'].includes(i.tipo) : i.tipo === filtro);
    const buscaOk = !termo || normalizar(i.nome).includes(termo) || normalizar(i.descricao ?? '').includes(termo);
    return tipoOk && buscaOk;
  });
}

/** Peso total de uma lista (peso × quantidade) */
export function pesoDosItens(itens: { peso: number; quantidade: number }[]): number {
  return Math.round(itens.reduce((s, i) => s + i.peso * i.quantidade, 0) * 100) / 100;
}

export interface SituacaoUso {
  tipo: TipoItem;
  slug: string;
  staminaAtual: number;
  staminaMaxima: number;
  ferimentos: number;
  recuperaStamina?: number | null;
  curaFerimento?: number | null;
}

/** Mesmo motivo do banco (motivo_nao_usar). null = pode usar */
export function motivoNaoUsar(s: SituacaoUso): string | null {
  if (s.tipo === 'recurso') return 'Recursos servem para construir e fabricar.';
  if (s.tipo === 'arma') return 'Armas são equipadas, não usadas.';
  if (s.tipo === 'item_chave') return 'Itens-chave funcionam sozinhos enquanto estiverem com você.';
  if (s.recuperaStamina) return s.staminaAtual >= s.staminaMaxima ? 'Sua stamina já está cheia.' : null;
  if (s.curaFerimento) return s.ferimentos <= 0 ? 'Você não está ferido.' : null;
  return 'Este item não pode ser usado agora.';
}

/** Stamina depois de usar (nunca passa do máximo) */
export function staminaDepoisDeUsar(atual: number, maxima: number, ganho: number): number {
  return Math.min(maxima, atual + Math.max(0, ganho));
}

/** Ferimentos depois de usar (nunca abaixo de zero) */
export function ferimentosDepoisDeUsar(atual: number, cura: number): number {
  return Math.max(0, atual - Math.max(0, cura));
}

/** Motivo para não descartar (null = pode) */
export function motivoNaoDescartar(i: { tipo: string; equipado: string | null; em_expedicao: boolean }, qtd: number, quantidade: number): string | null {
  if (i.tipo === 'item_chave') return 'Itens-chave não podem ser descartados.';
  if (i.equipado) return 'Desequipe a arma antes de descartar.';
  if (i.em_expedicao) return 'Essa arma está numa expedição.';
  if (!Number.isInteger(qtd) || qtd < 1 || qtd > quantidade) return 'Quantidade inválida.';
  return null;
}

/** Motivo para não equipar (null = pode) */
export function motivoNaoEquipar(i: { tipo: string; durabilidade: number | null; nivel_requisito: number }, nivel: number): string | null {
  if (i.tipo !== 'arma') return 'Só armas podem ser equipadas.';
  if ((i.durabilidade ?? 0) <= 0) return 'Essa arma está quebrada. Repare antes.';
  if (i.nivel_requisito > nivel) return `Essa arma exige nível ${i.nivel_requisito}.`;
  return null;
}
