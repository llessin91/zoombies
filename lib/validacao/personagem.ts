// src/lib/validacao/personagem.ts
// Validação (Zod) do que o navegador envia nas ações do personagem.
// Aqui só conferimos o FORMATO. As regras (limites, soma, pontos) são conferidas no banco.

import { z } from 'zod';

const pontoInteiro = z.number({ invalid_type_error: 'Valor inválido.' }).int('Use números inteiros.').min(0).max(100);

export const atributosSchema = z
  .object({
    forca: pontoInteiro,
    agilidade: pontoInteiro,
    percepcao: pontoInteiro,
    medicina: pontoInteiro,
    engenharia: pontoInteiro,
    lideranca: pontoInteiro,
  })
  .strict();

export const criarPersonagemSchema = atributosSchema;
export const distribuirPontosSchema = atributosSchema;

export type EntradaAtributos = z.infer<typeof atributosSchema>;
