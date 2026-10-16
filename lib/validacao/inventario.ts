// src/lib/validacao/inventario.ts
// Formato (Zod) do que o navegador envia nas ações de inventário. As regras ficam no banco.

import { z } from 'zod';

export const itemSchema = z.object({ id: z.string().uuid() }).strict();
export const desequiparSchema = z.object({ slot: z.enum(['arma_principal', 'arma_corpo_a_corpo']) }).strict();
export const descartarSchema = z.object({ id: z.string().uuid(), qtd: z.number().int().min(1).max(9999) }).strict();
