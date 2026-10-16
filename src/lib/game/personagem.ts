// src/lib/game/personagem.ts
// Formato do estado do personagem que o banco devolve (função estado_personagem).
// Validamos com Zod para a tela nunca quebrar com um dado inesperado.

import { z } from 'zod';

const numero = z.coerce.number();

// Contadores de estatística: o que faltar vira 0
function contador(v: unknown): number {
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
}

const statsSchema = z
  .record(z.unknown())
  .nullable()
  .transform((s) => ({
    missoes: contador(s?.missoes),
    sucessos: contador(s?.sucessos),
    falhas: contador(s?.falhas),
    sobreviventes_salvos: contador(s?.sobreviventes_salvos),
    zumbis_abatidos: contador(s?.zumbis_abatidos),
  }));

export const estadoPersonagemSchema = z.object({
  nome: z.string().nullable().transform((n) => n ?? 'Sobrevivente'),
  nivel: numero,
  nivel_anunciado: numero,
  xp: numero,
  xp_proximo: numero,
  pontos_disponiveis: numero,
  atributos: z.object({
    forca: numero,
    agilidade: numero,
    percepcao: numero,
    medicina: numero,
    engenharia: numero,
    lideranca: numero,
  }),
  atributo_maximo: numero,
  moral: numero,
  stamina_atual: numero,
  stamina_maxima: numero,
  stamina_atualizada_em: z.string(),
  segundos_por_ponto: numero,
  tutorial_etapa: numero,
  stats: statsSchema,
  criado_em: z.string(),
  dias_jogo_por_hora_real: numero,
  hora_inicial: numero,
  moral_divisor: numero,
  ferimentos: numero.default(0),
  ferimento_maximo: numero.default(3),
  equipamento: z
    .record(
      z.object({
        inventory_id: z.string(),
        slug: z.string(),
        nome: z.string(),
        raridade: z.string(),
        durabilidade: numero.nullable(),
        durabilidade_max: numero.nullable(),
        bonus: numero,
      }),
    )
    .default({}),
  itens_novos: z.boolean().default(false),
  expedicao: z
    .object({ id: z.string(), estado: z.string(), missao: z.string(), termina_em: z.string(), loot_pendente: z.boolean() })
    .nullable()
    .default(null),
  // Resumo do abrigo (Fase 7); null enquanto não escolheu
  abrigo: z
    .object({
      nome: z.string(),
      comida: numero,
      agua: numero,
      combustivel: numero,
      energia_ok: z.boolean(),
      tem_energia: z.boolean(),
      producao_pronta: numero,
      construindo: numero,
      alertas: numero,
    })
    .nullable()
    .default(null),
  // Bônus das instalações nos atributos (Treinamento, Oficina, Enfermaria)
  bonus_abrigo: z.record(numero).nullable().default(null),
  servidor_agora: z.string(),
});

export type EstadoPersonagem = z.infer<typeof estadoPersonagemSchema>;

/** Converte a resposta do banco. Devolve null se ainda não existe personagem. */
export function lerEstadoPersonagem(dados: unknown): EstadoPersonagem | null {
  if (dados === null || dados === undefined) return null;
  return estadoPersonagemSchema.parse(dados);
}
