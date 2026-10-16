// src/lib/game/abrigo.ts
// Regras do abrigo em TypeScript. A simulação espelha a função SQL sincronizar_abrigo (migration 0010):
// dia a dia, o gerador gasta combustível, a energia é calculada, e cada instalação de produção avança
// o ciclo, paga a manutenção e produz o que couber no depósito. Quem grava é o banco; aqui ficam os testes
// e o formato do estado que a tela recebe.

import { z } from 'zod';

export interface InstalacaoSim {
  id: string;
  /** Item produzido e quantidade por ciclo */
  item: string;
  qtd: number;
  cicloDias: number;
  /** Manutenção: itens consumidos a cada N ciclos (vazio = sem manutenção) */
  manutencao?: { itens: Record<string, number>; aCadaCiclos: number };
  consumoEnergia: number;
  /** Dias dentro do ciclo atual (negativo = ainda não estava pronta) */
  progressoDias: number;
  ciclos: number;
  acumulada: number;
  parada: boolean;
}

export interface GeradorSim {
  cobre: number;
  diasPorCombustivel: number;
}

export interface EstadoSim {
  deposito: Record<string, number>;
  /** Peso de cada item (padrão 1) */
  pesos?: Record<string, number>;
  capacidade: number;
  gerador: GeradorSim | null;
  painelSolar: number;
  combustivelProgresso: number;
  /** Demanda de recrutas (Fase 8) */
  recrutas: number;
  instalacoes: InstalacaoSim[];
}

export interface ResultadoSim {
  estado: EstadoSim;
  energiaOk: boolean;
  combustivelGasto: number;
  diasSimulados: number;
}

function peso(e: EstadoSim, item: string) {
  return e.pesos?.[item] ?? 1;
}

export function usoDeposito(e: EstadoSim): number {
  return Object.entries(e.deposito).reduce((s, [k, q]) => s + q * peso(e, k), 0);
}

export function usoAcumulado(e: EstadoSim): number {
  return e.instalacoes.reduce((s, i) => s + Math.floor(i.acumulada) * peso(e, i.item), 0);
}

function tirar(e: EstadoSim, item: string, qtd: number): boolean {
  if ((e.deposito[item] ?? 0) < qtd) return false;
  e.deposito[item] -= qtd;
  return true;
}

/**
 * Simula `dias` dias do jogo. Produção só nos primeiros `maxDiasProducao`;
 * o consumo de combustível vale para todos os dias.
 */
export function simularAbrigo(inicial: EstadoSim, dias: number, maxDiasProducao = 30): ResultadoSim {
  const e: EstadoSim = structuredClone(inicial);
  let semCombustivel = false;
  let energiaOk = true;
  let combustivelGasto = 0;
  const n = Math.max(0, Math.floor(dias));

  for (let d = 1; d <= n; d++) {
    // Energia do dia
    let oferta = 0;
    if (e.gerador && !semCombustivel) {
      e.combustivelProgresso += 1;
      if (e.combustivelProgresso >= e.gerador.diasPorCombustivel) {
        if (tirar(e, 'combustivel', 1)) {
          e.combustivelProgresso -= e.gerador.diasPorCombustivel;
          combustivelGasto += 1;
        } else {
          semCombustivel = true;
        }
      }
      if (!semCombustivel) oferta += e.gerador.cobre;
    }
    oferta += e.painelSolar;
    const demanda = e.instalacoes.reduce((s, i) => s + i.consumoEnergia, 0) + e.recrutas;
    energiaOk = oferta >= demanda;

    if (d > maxDiasProducao) continue;

    for (const inst of e.instalacoes) {
      if (inst.consumoEnergia > 0 && !energiaOk) continue;
      inst.progressoDias += 1;
      if (inst.progressoDias < inst.cicloDias) continue;
      inst.progressoDias -= inst.cicloDias;
      inst.ciclos += 1;

      // Manutenção
      if (inst.manutencao && inst.ciclos % inst.manutencao.aCadaCiclos === 0) {
        const ok = Object.entries(inst.manutencao.itens).every(([k, q]) => (e.deposito[k] ?? 0) >= q);
        if (!ok) {
          inst.parada = true;
          continue;
        }
        for (const [k, q] of Object.entries(inst.manutencao.itens)) tirar(e, k, q);
      }
      inst.parada = false;

      // Produz o que couber
      const livre = e.capacidade - usoDeposito(e) - usoAcumulado(e);
      const p = peso(e, inst.item);
      const qtd = p > 0 ? Math.min(inst.qtd, Math.floor(Math.max(0, livre) / p)) : inst.qtd;
      if (qtd > 0) inst.acumulada += qtd;
    }
  }
  return { estado: e, energiaOk, combustivelGasto, diasSimulados: n };
}

/** Dias que o combustível ainda dura (null = sem gerador) */
export function diasDeCombustivel(combustivel: number, diasPorCombustivel: number | null, progresso: number): number | null {
  if (diasPorCombustivel === null) return null;
  return Math.max(0, combustivel * diasPorCombustivel + (diasPorCombustivel - progresso));
}

/** Capacidade do depósito: base + bônus das instalações "Depósito" */
export function capacidadeDeposito(base: number, bonus: number[]): number {
  return base + bonus.reduce((s, b) => s + b, 0);
}

/** Quanto cabe de um item no depósito */
export function quantoCabe(qtd: number, pesoItem: number, livre: number): number {
  if (pesoItem <= 0) return qtd;
  return Math.max(0, Math.min(qtd, Math.floor(livre / pesoItem)));
}

// ---------------------------------------------------------------------------
// Formato do estado do abrigo devolvido pelo banco (estado_abrigo)
// ---------------------------------------------------------------------------
const n = z.coerce.number();
const jsonLivre = z.record(z.unknown()).nullable().transform((v) => v ?? {});

const opcaoAbrigoSchema = z.object({
  slug: z.string(),
  nome: z.string(),
  descricao: z.string(),
  slots: n,
  vantagens: jsonLivre,
  desvantagens: jsonLivre,
  local: z.string().nullable(),
  regiao: z.string().nullable(),
});

const instalacaoSchema = z.object({
  id: z.string(),
  slug: z.string(),
  nome: z.string(),
  categoria: z.enum(['estrutural', 'energia', 'producao']),
  descricao: z.string(),
  nivel: n,
  nome_nivel: z.string().nullable(),
  max_nivel: n,
  estado: z.enum(['construindo', 'ativo', 'danificado', 'parado']),
  slot: n.nullable(),
  concluido_em: z.string().nullable(),
  criado_em: z.string(),
  producao: jsonLivre,
  manutencao: jsonLivre,
  efeitos: jsonLivre,
  item_produzido: z.string().nullable(),
  item_produzido_nome: z.string().nullable(),
  acumulada: n,
  progresso_dias: n,
  consumo_energia: n,
  tempo_dias: n,
  sem_energia: z.boolean(),
  desmontavel: z.boolean(),
  melhoria: z.object({ nome: z.string().nullable(), custo: jsonLivre, custo_texto: z.string(), motivo: z.string().nullable() }).nullable(),
  reparo_custo: z.string().nullable(),
});

const catalogoSchema = z.object({
  slug: z.string(),
  nome: z.string(),
  categoria: z.enum(['estrutural', 'energia', 'producao']),
  descricao: z.string(),
  custo: jsonLivre,
  custo_itens: z.array(z.object({ item: z.string(), nome: z.string(), qtd: n, tem: n })),
  tempo_dias: n,
  efeitos: jsonLivre,
  producao: jsonLivre,
  consumo_energia: n,
  nome_nivel: z.string().nullable(),
  motivo: z.string().nullable(),
});

export const estadoAbrigoSchema = z.union([
  z.object({ tem_abrigo: z.literal(false), escolha: z.array(opcaoAbrigoSchema), servidor_agora: z.string() }),
  z.object({
    tem_abrigo: z.literal(true),
    abrigo: z.object({
      id: z.string(),
      slug: z.string(),
      nome: z.string(),
      descricao: z.string(),
      local: z.string().nullable(),
      regiao: z.string().nullable(),
      regiao_nome: z.string().nullable(),
      slots: n,
      vantagens: jsonLivre,
      desvantagens: jsonLivre,
      criado_em: z.string(),
    }),
    deposito: z.object({
      capacidade: n,
      usado: n,
      itens: z.array(z.object({ id: z.string(), slug: z.string(), nome: z.string(), tipo: z.string(), raridade: z.string(), quantidade: n, peso: n })),
    }),
    energia: z.object({
      oferta: n,
      demanda: n,
      estado: z.enum(['ok', 'apertado', 'sem_energia', 'sem_gerador']),
      combustivel: n,
      dias_combustivel: n.nullable(),
    }),
    defesa: z.enum(['forte', 'razoavel', 'fraca', 'nenhuma']),
    ameaca: z.enum(['alta', 'media', 'baixa']),
    instalacoes: z.array(instalacaoSchema),
    catalogo: z.array(catalogoSchema),
    alertas: z.array(z.object({ tipo: z.string(), texto: z.string() })),
    dias_jogo_por_hora_real: n,
    servidor_agora: z.string(),
    coletado: n.optional(),
  }),
]);

export type EstadoAbrigo = z.infer<typeof estadoAbrigoSchema>;
export type EstadoAbrigoCom = Extract<EstadoAbrigo, { tem_abrigo: true }>;
export type Instalacao = EstadoAbrigoCom['instalacoes'][number];
export type ItemCatalogoAbrigo = EstadoAbrigoCom['catalogo'][number];
export type OpcaoAbrigo = Extract<EstadoAbrigo, { tem_abrigo: false }>['escolha'][number];

export function lerEstadoAbrigo(dados: unknown): EstadoAbrigo {
  return estadoAbrigoSchema.parse(dados);
}

/** Texto das vantagens e desvantagens (com números, como pede a tela de escolha) */
export function descreverVantagens(v: Record<string, unknown>): string[] {
  const t: string[] = [];
  if (v.stamina_max_bonus_pct) t.push(`+${v.stamina_max_bonus_pct}% de stamina máxima`);
  if (v.engenharia_bonus_pct) t.push(`+${v.engenharia_bonus_pct}% de Engenharia efetiva`);
  if (v.forja_basica) t.push('Forja básica disponível');
  if (v.recursos_basicos_iniciais) t.push(`Começa com ${v.recursos_basicos_iniciais} de cada recurso básico`);
  if (v.comida_inicial || v.agua_inicial) t.push(`${v.comida_inicial ?? 0} de comida e ${v.agua_inicial ?? 0} de água no depósito`);
  if (v.agilidade_bonus_pct_periferia) t.push(`+${v.agilidade_bonus_pct_periferia}% de Agilidade na Periferia`);
  if (v.furtividade_bonus_pct_periferia) t.push(`+${v.furtividade_bonus_pct_periferia}% de furtividade na Periferia`);
  return t;
}

export function descreverDesvantagens(v: Record<string, unknown>): string[] {
  const t: string[] = [];
  if (v.espaco_reduzido) t.push('Espaço reduzido: menos espaços para instalações');
  if (v.ruido_ataque_mult) t.push(`Mais barulho: chance de ataque × ${v.ruido_ataque_mult}`);
  if (v.custo_stamina_saida_extra) t.push(`+${v.custo_stamina_saida_extra} de stamina para sair em missões (até construir a Saída reforçada)`);
  if (v.dano_ataque_mult) t.push(`Estrutura frágil: dano de ataques × ${v.dano_ataque_mult}`);
  if (v.reconstrucao_custo_mult) t.push(`Reconstrução × ${v.reconstrucao_custo_mult} mais cara`);
  return t;
}

// ---------------------------------------------------------------------------
// Textos das instalações (só exibição)
// ---------------------------------------------------------------------------
const NOMES_ITENS: Record<string, string> = {
  comida_enlatada: 'comida',
  agua_potavel: 'água',
  combustivel: 'combustível',
  sucata: 'sucata',
  metal: 'metal',
  madeira: 'madeira',
};
const ATRIB: Record<string, string> = {
  forca: 'Força',
  agilidade: 'Agilidade',
  percepcao: 'Percepção',
  medicina: 'Medicina',
  engenharia: 'Engenharia',
  lideranca: 'Liderança',
};

function nomeItem(slug: string) {
  return NOMES_ITENS[slug] ?? slug.replace(/_/g, ' ');
}

/** "1 comida a cada 2 dias" */
export function textoProducao(p: Record<string, unknown>): string | null {
  const ciclo = Number(p.ciclo_dias ?? 0);
  const itens = Object.entries(p).filter(([k]) => k !== 'ciclo_dias' && typeof p[k] === 'number');
  if (!ciclo || itens.length === 0) return null;
  const quanto = itens.map(([k, q]) => `${q} ${nomeItem(k)}`).join(' + ');
  return `${quanto} ${ciclo === 1 ? 'por dia' : `a cada ${ciclo} dias`}`;
}

/** "consome 1 comida a cada 5 ciclos" */
export function textoManutencao(m: Record<string, unknown>): string | null {
  const a = Number(m.a_cada_ciclos ?? 0);
  const itens = Object.entries(m).filter(([k]) => k !== 'a_cada_ciclos' && typeof m[k] === 'number');
  if (!a || itens.length === 0) return null;
  const quanto = itens.map(([k, q]) => `${q} ${nomeItem(k)}`).join(' + ');
  return `Manutenção: ${quanto} ${a === 1 ? 'por ciclo' : `a cada ${a} ciclos`}`;
}

/** Lista curta do que a instalação faz */
export function textoEfeitos(e: Record<string, unknown>): string[] {
  const t: string[] = [];
  const bonus = e.atributo_bonus as Record<string, number> | undefined;
  if (bonus) t.push(Object.entries(bonus).map(([k, v]) => `+${v} ${ATRIB[k] ?? k}`).join(', '));
  if (e.defesa) t.push(`Defesa +${e.defesa}`);
  if (e.alerta_ataque) t.push('Avisa antes de ataques');
  if (e.capacidade_deposito_bonus) t.push(`Depósito +${e.capacidade_deposito_bonus}`);
  if (e.cobre_recrutas) t.push(`Energia: ${e.cobre_recrutas}`);
  if (e.dias_por_combustivel) t.push(`1 combustível a cada ${e.dias_por_combustivel} dias`);
  if (e.recrutas_max_bonus) t.push(`+${e.recrutas_max_bonus} vaga de recruta`);
  if (e.remove_custo_stamina_saida) t.push('Remove o custo extra de stamina para sair');
  if (e.consumo_comida_reducao_pct) t.push(`Consumo de comida −${e.consumo_comida_reducao_pct}%`);
  if (e.desbloqueia_fabricacao) t.push('Libera receitas de fabricação');
  if (e.recrutamento_bonus) t.push('Melhora o recrutamento');
  return t;
}

export const ROTULO_ENERGIA: Record<EstadoAbrigoCom['energia']['estado'], string> = {
  ok: 'Energia sobrando',
  apertado: 'Energia no limite',
  sem_energia: 'Sem energia',
  sem_gerador: 'Sem gerador',
};
export const ROTULO_DEFESA: Record<EstadoAbrigoCom['defesa'], string> = { forte: 'Forte', razoavel: 'Razoável', fraca: 'Fraca', nenhuma: 'Nenhuma' };
export const ROTULO_AMEACA: Record<EstadoAbrigoCom['ameaca'], string> = { alta: 'Alta', media: 'Média', baixa: 'Baixa' };
export const ROTULO_CATEGORIA: Record<'estrutural' | 'energia' | 'producao', string> = {
  estrutural: 'Estruturais',
  energia: 'Energia',
  producao: 'Produção',
};
