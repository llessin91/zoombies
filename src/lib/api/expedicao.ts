// src/lib/api/expedicao.ts
// Peças comuns das rotas de expedição: valida o id da URL e lê a resposta do banco.

import { NextResponse } from 'next/server';
import { lerEstadoExpedicao } from '@/lib/game/expedicao';
import { idExpedicaoSchema } from '@/lib/validacao/expedicao';
import { mensagemErroBanco, respostaErro } from './acao';

export function idValido(id: string): boolean {
  return idExpedicaoSchema.safeParse(id).success;
}

export function responderEstado(data: unknown, error: { code?: string; message?: string } | null) {
  if (error) {
    const e = mensagemErroBanco(error);
    return respostaErro(e.mensagem, e.status);
  }
  return NextResponse.json({ ok: true, expedicao: lerEstadoExpedicao(data) });
}
