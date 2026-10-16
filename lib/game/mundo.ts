// src/lib/game/mundo.ts
// Monta no servidor tudo o que as telas Mapa e Missões precisam:
// catálogo (regiões, locais, missões, itens) + estado do jogador calculado pelo banco (estado_mundo).
// A chance de cada missão chega só como FAIXA; o número fica no banco.

import { z } from 'zod';
import type { SupabaseClient } from '@supabase/supabase-js';
import type { Dificuldade } from './config';
import type { Categoria, EstadoMissao, FaixaChance } from './missoes';

const estadoMundoSchema = z.object({
  nivel: z.coerce.number(),
  regioes: z.array(z.object({ slug: z.string(), liberada: z.boolean(), motivo: z.string().nullable() })),
  locais_esgotados: z.array(z.object({ slug: z.string(), disponivel_em: z.string(), dias_restantes: z.coerce.number() })),
  missoes: z.array(
    z.object({
      slug: z.string(),
      custo_stamina: z.coerce.number(),
      duracao_segundos: z.coerce.number(),
      xp: z.coerce.number(),
      faixa: z.enum(['segura', 'equilibrada', 'arriscada', 'muito_arriscada']).nullable(),
      estado: z.enum(['disponivel', 'bloqueada', 'esgotada']),
      motivo: z.string().nullable(),
    }),
  ),
  carga_maxima: z.coerce.number(),
  dias_jogo_por_hora_real: z.coerce.number(),
  servidor_agora: z.string(),
});

export interface ItemCatalogo {
  slug: string;
  nome: string;
  tipo: 'recurso' | 'consumivel' | 'arma' | 'item_chave';
  raridade: string;
  peso: number;
}

export interface LootPossivel {
  item: string;
  chance: number;
  min: number;
  max: number;
  alta_qualidade?: boolean;
}

export interface RegiaoMundo {
  slug: string;
  nome: string;
  descricao: string;
  nivelMinimo: number;
  itemAcesso: string | null;
  liberada: boolean;
  motivo: string | null;
}

export interface LocalMundo {
  slug: string;
  nome: string;
  descricao: string;
  regiao: string;
  /** Dias do jogo até voltar (null = disponível) */
  esgotadoDias: number | null;
  ehAbrigo: boolean;
}

export interface MissaoMundo {
  slug: string;
  nome: string;
  local: string;
  regiao: string;
  ponto: string | null;
  categoria: Categoria;
  dificuldade: Dificuldade;
  pesos: Record<string, number>;
  loot: LootPossivel[];
  especial: { riscos?: string[]; ruido?: number; recruta_chance?: number };
  abertura: string;
  nivelRequerido: number;
  custoStamina: number;
  duracaoSegundos: number;
  xp: number;
  faixa: FaixaChance | null;
  estado: EstadoMissao;
  motivo: string | null;
}

export interface ItemMochila {
  /** Linha do inventário (armas têm uma linha por unidade) */
  id: string;
  slug: string;
  nome: string;
  tipo: ItemCatalogo['tipo'];
  quantidade: number;
  durabilidade: number | null;
  peso: number;
  /** Onde está: mochila ou depósito do abrigo (consumíveis do depósito também podem ser levados) */
  local: 'mochila' | 'deposito';
}

export interface MundoJogador {
  nivel: number;
  regioes: RegiaoMundo[];
  locais: LocalMundo[];
  missoes: MissaoMundo[];
  itens: Record<string, ItemCatalogo>;
  mochila: ItemMochila[];
  cargaMaxima: number;
  abrigoLocal: string | null;
}

export type ResultadoMundo = { ok: true; mundo: MundoJogador } | { ok: false; faltaAtualizar: boolean };

export async function carregarMundo(supabase: SupabaseClient): Promise<ResultadoMundo> {
  const [estadoR, regioesR, locaisR, missoesR, itensR, mochilaR, abrigoR] = await Promise.all([
    supabase.rpc('estado_mundo'),
    supabase.from('regions').select('id, slug, nome, descricao, ordem, nivel_minimo, item_acesso_slug').order('ordem'),
    supabase.from('locations').select('id, slug, nome, descricao, ordem, region_id').order('ordem'),
    supabase
      .from('missions')
      .select('slug, nome, location_id, ponto, categoria, dificuldade, pesos, loot, requisitos, especial, textos, ordem')
      .eq('ativa', true)
      .order('ordem'),
    supabase.from('items').select('id, slug, nome, tipo, raridade, peso'),
    supabase.from('inventory').select('id, item_id, quantidade, durabilidade, local'),
    supabase.from('user_shelters').select('shelter_id').eq('ativo', true).limit(1),
  ]);

  const erro = estadoR.error ?? regioesR.error ?? locaisR.error ?? missoesR.error ?? itensR.error ?? mochilaR.error ?? abrigoR.error;
  if (erro) {
    console.error('[carregarMundo]', erro.code, erro.message);
    // Coluna ou função que não existe = falta rodar o SQL desta fase
    return { ok: false, faltaAtualizar: ['PGRST202', '42883', '42703', 'PGRST204'].includes(erro.code ?? '') };
  }

  const lido = estadoMundoSchema.safeParse(estadoR.data);
  if (!lido.success) {
    console.error('[estado_mundo formato]', lido.error.issues[0]);
    return { ok: false, faltaAtualizar: true };
  }
  const est = lido.data;

  // Abrigo ativo: em qual local ele fica (para o marcador do mapa)
  let abrigoLocalId: string | null = null;
  const abrigo = abrigoR.data?.[0] as { shelter_id: string } | undefined;
  if (abrigo) {
    const { data } = await supabase.from('shelters').select('location_id').eq('id', abrigo.shelter_id).maybeSingle();
    abrigoLocalId = (data as { location_id: string | null } | null)?.location_id ?? null;
  }

  const regioesPorId = new Map((regioesR.data ?? []).map((r) => [r.id as string, r.slug as string]));
  const locaisPorId = new Map((locaisR.data ?? []).map((l) => [l.id as string, l]));
  const estadoRegiao = new Map(est.regioes.map((r) => [r.slug, r]));
  const esgotados = new Map(est.locais_esgotados.map((l) => [l.slug, l.dias_restantes]));
  const estadoMissao = new Map(est.missoes.map((m) => [m.slug, m]));

  const itensPorId = new Map((itensR.data ?? []).map((i) => [i.id as string, i]));
  const itens: Record<string, ItemCatalogo> = {};
  for (const i of itensR.data ?? []) {
    itens[i.slug as string] = { slug: i.slug, nome: i.nome, tipo: i.tipo, raridade: i.raridade, peso: Number(i.peso) };
  }

  const regioes: RegiaoMundo[] = (regioesR.data ?? []).map((r) => ({
    slug: r.slug,
    nome: r.nome,
    descricao: r.descricao,
    nivelMinimo: r.nivel_minimo,
    itemAcesso: r.item_acesso_slug,
    liberada: estadoRegiao.get(r.slug)?.liberada ?? false,
    motivo: estadoRegiao.get(r.slug)?.motivo ?? null,
  }));

  const locais: LocalMundo[] = (locaisR.data ?? []).map((l) => ({
    slug: l.slug,
    nome: l.nome,
    descricao: l.descricao,
    regiao: regioesPorId.get(l.region_id) ?? '',
    esgotadoDias: esgotados.get(l.slug) ?? null,
    ehAbrigo: abrigoLocalId === l.id,
  }));

  const missoes: MissaoMundo[] = [];
  for (const m of missoesR.data ?? []) {
    const e = estadoMissao.get(m.slug);
    const local = locaisPorId.get(m.location_id);
    if (!e || !local) continue;
    const textos = (m.textos ?? {}) as { abertura?: string };
    const requisitos = (m.requisitos ?? {}) as { nivel?: number };
    missoes.push({
      slug: m.slug,
      nome: m.nome,
      local: local.slug,
      regiao: regioesPorId.get(local.region_id) ?? '',
      ponto: m.ponto,
      categoria: m.categoria,
      dificuldade: m.dificuldade,
      pesos: m.pesos ?? {},
      loot: (m.loot ?? []) as LootPossivel[],
      especial: m.especial ?? {},
      abertura: textos.abertura ?? '',
      nivelRequerido: Number(requisitos.nivel ?? 1),
      custoStamina: e.custo_stamina,
      duracaoSegundos: e.duracao_segundos,
      xp: e.xp,
      faixa: e.faixa,
      estado: e.estado,
      motivo: e.motivo,
    });
  }

  const mochila: ItemMochila[] = (mochilaR.data ?? []).flatMap((linha) => {
    const it = itensPorId.get(linha.item_id);
    if (!it) return [];
    const local = linha.local === 'deposito' ? 'deposito' : 'mochila';
    // Do depósito só interessam os consumíveis (armas sempre ficam na mochila)
    if (local === 'deposito' && it.tipo !== 'consumivel') return [];
    return [{ id: linha.id as string, slug: it.slug, nome: it.nome, tipo: it.tipo, quantidade: linha.quantidade, durabilidade: linha.durabilidade, peso: Number(it.peso), local }];
  });

  const abrigoLocal = locais.find((l) => l.ehAbrigo)?.slug ?? null;

  return { ok: true, mundo: { nivel: est.nivel, regioes, locais, missoes, itens, mochila, cargaMaxima: est.carga_maxima, abrigoLocal } };
}
