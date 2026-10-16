// src/lib/validacao/expedicao.ts
// Formato (Zod) do que o navegador envia nas ações de expedição. As regras ficam no banco.

import { z } from 'zod';

const slug = z.string().min(1).max(80).regex(/^[a-z0-9_]+$/, 'Valor inválido.');

export const iniciarExpedicaoSchema = z
  .object({
    missao: slug,
    arma: z.string().uuid().nullable().optional(),
    consumiveis: z.array(z.object({ item: slug, qtd: z.number().int().min(1).max(10) }).strict()).max(10).default([]),
  })
  .strict();

export const resolverEventoSchema = z.object({ opcao: z.number().int().min(0).max(10) }).strict();

export const finalizarExpedicaoSchema = z.object({ pular: z.boolean().default(false) }).strict();

export const confirmarLootSchema = z.object({ escolha: z.record(slug, z.number().int().min(0).max(999)) }).strict();

export const idExpedicaoSchema = z.string().uuid();
