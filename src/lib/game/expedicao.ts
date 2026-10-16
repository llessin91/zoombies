// src/lib/game/expedicao.ts
// Regras da expedição em TypeScript, espelhando a migration 0008 (finalizar_expedicao, atualizar_expedicao).
// O resultado de verdade é sorteado no banco. Aqui ficam: progresso da barra (para a tela),
// textos e as mesmas contas usadas nos testes.

import { z } from 'zod';

export type Desfecho = 'total' | 'parcial' | 'fracasso';

/** Rolagem 1–100 contra a chance P: total (≤ P), parcial (≤ P + margem), fracasso */
export function classificarDesfecho(rolagem: number, p: number, margemParcial = 15): Desfecho {
  if (rolagem <= p) return 'total';
  if (rolagem <= p + margemParcial) return 'parcial';
  return 'fracasso';
}

export interface ConstantesResultado {
  parcialLootPct: number;
  parcialXpPct: number;
  falhaXpPct: number;
}

export const RESULTADO_PADRAO: ConstantesResultado = { parcialLootPct: 50, parcialXpPct: 50, falhaXpPct: 15 };

/** Quantidade de um item do saque conforme o desfecho (arredonda para baixo; fracasso = 0) */
export function quantidadeLoot(qtd: number, desfecho: Desfecho, c: ConstantesResultado = RESULTADO_PADRAO): number {
  if (desfecho === 'fracasso') return 0;
  if (desfecho === 'parcial') return Math.floor((qtd * c.parcialLootPct) / 100);
  return qtd;
}

/** XP ganho conforme o desfecho, mais o bônus do evento */
export function xpDoDesfecho(xpBase: number, desfecho: Desfecho, xpEvento = 0, c: ConstantesResultado = RESULTADO_PADRAO): number {
  const pct = desfecho === 'total' ? 100 : desfecho === 'parcial' ? c.parcialXpPct : c.falhaXpPct;
  return Math.floor((xpBase * pct) / 100) + xpEvento;
}

/** Perda percentual do saque (ex.: vazamento de 30%) */
export function aplicarPerda(qtd: number, perdaPct: number): number {
  return Math.floor((qtd * (100 - perdaPct)) / 100);
}

export interface ItemSaque {
  item: string;
  qtd: number;
  peso: number;
}

/** Peso total do saque */
export function pesoTotal(itens: ItemSaque[]): number {
  return itens.reduce((s, i) => s + i.qtd * i.peso, 0);
}

/** Cabe na mochila? (capacidade menos o que já foi levado, como a arma) */
export function cargaDisponivel(cargaMax: number, pesoLevado: number): number {
  return Math.max(0, cargaMax - pesoLevado);
}

/** Escolha de "o que levar" é válida? */
export function validarEscolhaLoot(saque: ItemSaque[], escolha: Record<string, number>, disponivel: number): string | null {
  let peso = 0;
  for (const s of saque) {
    const q = escolha[s.item] ?? 0;
    if (!Number.isInteger(q) || q < 0 || q > s.qtd) return 'Quantidade inválida.';
    peso += q * s.peso;
  }
  if (peso > disponivel) return 'Ainda está pesado demais. Deixe mais coisas para trás.';
  return null;
}

/** Chance de se ferir no fracasso, reduzida por bandagem/kit levados (nunca negativa) */
export function chanceFerimento(base: number, levados: { item: string; qtd: number }[], reducao: Record<string, number>): number {
  return Math.max(0, levados.reduce((c, l) => c - (reducao[l.item] ?? 0) * l.qtd, base));
}

/** Desgaste da arma: dobra no fracasso; nunca abaixo de zero */
export function durabilidadeDepois(atual: number, desgaste: number, desfecho: Desfecho): number {
  return Math.max(0, atual - desgaste * (desfecho === 'fracasso' ? 2 : 1));
}

export interface OpcaoEvento {
  indice: number;
  risco: number;
  cautelosa?: boolean;
  temRequisito?: boolean;
  temCusto?: boolean;
}

/** Opção aplicada sozinha quando o prazo acaba: a "cautelosa"; senão a de menor risco sem requisito nem custo */
export function opcaoCautelosa(opcoes: OpcaoEvento[]): number {
  const livres = opcoes.filter((o) => !o.temRequisito && !o.temCusto);
  const ordenadas = [...livres].sort((a, b) => Number(Boolean(b.cautelosa)) - Number(Boolean(a.cautelosa)) || a.risco - b.risco || a.indice - b.indice);
  return ordenadas[0]?.indice ?? 0;
}

/**
 * Progresso da barra (0 a 1) no horário `agoraMs`.
 * Enquanto a decisão do evento espera, a barra fica parada no ponto do evento.
 */
export function progressoExpedicao(p: {
  iniciadaMs: number;
  duracaoSeg: number;
  pausaSeg: number;
  agoraMs: number;
  eventoEm: number | null;
  eventoResolvido: boolean;
  aguardandoEvento: boolean;
}): number {
  const corrido = (p.agoraMs - p.iniciadaMs) / 1000 - p.pausaSeg;
  let prog = p.duracaoSeg > 0 ? corrido / p.duracaoSeg : 1;
  // Evento ainda não decidido: a barra não passa do marcador
  if (p.eventoEm !== null && !p.eventoResolvido) prog = Math.min(prog, p.eventoEm);
  if (p.aguardandoEvento && p.eventoEm !== null) prog = p.eventoEm;
  return Math.min(1, Math.max(0, prog));
}

// ---------------------------------------------------------------------------
// Formato do estado da expedição devolvido pelo banco (montar_estado_expedicao)
// ---------------------------------------------------------------------------
const n = z.coerce.number();

const itemSaqueSchema = z.object({
  item: z.string(),
  qtd: n,
  nome: z.string().nullable().optional(),
  tipo: z.string().nullable().optional(),
  raridade: z.string().nullable().optional(),
  peso: n,
});

export const estadoExpedicaoSchema = z.object({
  id: z.string(),
  estado: z.enum(['em_andamento', 'aguardando_evento', 'concluida', 'expirada']),
  missao: z.object({
    slug: z.string(),
    nome: z.string(),
    dificuldade: z.enum(['facil', 'media', 'dificil', 'lendaria']),
    categoria: z.string(),
    regiao: z.string(),
    local: z.string(),
    ponto: z.string().nullable(),
  }),
  iniciada_em: z.string(),
  termina_em: z.string(),
  duracao_seg: n,
  pausa_seg: n,
  evento_em: n.nullable(),
  evento_aberto_em: z.string().nullable(),
  evento_resolvido: z.boolean(),
  tem_evento: z.boolean(),
  evento: z
    .object({
      titulo: z.string(),
      texto: z.string(),
      prazo_em: z.string(),
      opcoes: z.array(
        z.object({
          indice: n,
          titulo: z.string(),
          descricao: z.string().nullable(),
          risco: n,
          recompensa: n,
          cautelosa: z.boolean(),
          custo: z
            .object({ item: z.string().optional(), qtd: n.optional(), nome: z.string().nullable().optional(), ok: z.boolean().optional(), stamina: n.optional() })
            .nullable(),
          requisito: z.object({ atributo: z.string(), valor: n, ok: z.boolean() }).nullable(),
        }),
      ),
    })
    .nullable(),
  log: z.array(z.object({ pct: n, texto: z.string(), evento: z.boolean().optional(), fim: z.boolean().optional() })),
  custo_stamina: n,
  carga_max: n,
  peso_levado: n,
  resultado: z
    .object({
      desfecho: z.enum(['total', 'parcial', 'fracasso']),
      texto: z.string(),
      loot: z.array(itemSaqueSchema),
      peso_loot: n,
      carga_disponivel: n,
      excesso: z.boolean(),
      xp_ganho: n,
      niveis_ganhos: n,
      moral: n,
      ferido: z.boolean(),
      ferimentos: n,
      stamina_gasta: n,
      arma_durabilidade: n.nullable(),
      zumbis: n,
      recruta_encontrado: z.boolean(),
      evento: z.object({ titulo: z.string().nullable(), opcao: z.string().nullable(), texto: z.string().nullable() }).nullable(),
      levado: z.array(z.object({ item: z.string(), qtd: n })).optional(),
    })
    .nullable(),
  loot_entregue: z.boolean(),
  servidor_agora: z.string(),
});

export type EstadoExpedicao = z.infer<typeof estadoExpedicaoSchema>;
export type ItemSaqueTela = z.infer<typeof itemSaqueSchema>;

export function lerEstadoExpedicao(dados: unknown): EstadoExpedicao {
  return estadoExpedicaoSchema.parse(dados);
}
