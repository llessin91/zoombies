// src/lib/validacao/abrigo.ts
// Formato (Zod) do que o navegador envia nas ações do abrigo. As regras ficam no banco.

import { z } from 'zod';

const slug = z.string().regex(/^[a-z0-9_]{2,40}$/);

export const escolherAbrigoSchema = z.object({ slug }).strict();
export const construirSchema = z.object({ tipo: slug, slot: z.number().int().min(0).max(30).nullable().optional() }).strict();
export const instalacaoSchema = z.object({ id: z.string().uuid() }).strict();
export const coletarSchema = z.object({ id: z.string().uuid().nullable().optional() }).strict();
export const reciclarSchema = z.object({ produto: z.enum(['metal', 'componentes']), vezes: z.number().int().min(1).max(50) }).strict();
export const transferirSchema = z
  .object({ id: z.string().uuid(), qtd: z.number().int().min(1).max(9999), destino: z.enum(['mochila', 'deposito']) })
  .strict();
