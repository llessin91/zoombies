// src/lib/api/acao.ts
// Esqueleto comum das ações do jogo (route handlers em src/app/api):
// 1) confere a sessão, 2) aplica o limite de pedidos, 3) valida a entrada com Zod,
// 4) chama a função do banco (que confere as regras dentro de uma transação),
// 5) devolve mensagens amigáveis, sem vazar detalhes internos.

import { NextResponse } from 'next/server';
import type { ZodType } from 'zod';
import type { SupabaseClient, User } from '@supabase/supabase-js';
import { criarClienteServidor } from '@/lib/supabase/server';
import { dentroDoLimite } from './limiteTaxa';

export { mensagemErroBanco } from './erros';

export function respostaErro(mensagem: string, status: number) {
  return NextResponse.json({ ok: false, erro: mensagem }, { status });
}

interface OpcoesAcao<T> {
  nome: string;
  schema?: ZodType<T>;
  /** Máximo de pedidos por janela (padrão: 20 a cada 10 segundos) */
  limite?: { maximo: number; janelaMs: number };
  executar: (ctx: { supabase: SupabaseClient; user: User; dados: T }) => Promise<NextResponse>;
}

export async function executarAcao<T>(req: Request, opcoes: OpcoesAcao<T>): Promise<NextResponse> {
  try {
    const supabase = criarClienteServidor();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return respostaErro('Sessão expirada. Entre de novo.', 401);

    const limite = opcoes.limite ?? { maximo: 20, janelaMs: 10_000 };
    if (!dentroDoLimite(`${opcoes.nome}:${user.id}`, limite.maximo, limite.janelaMs)) {
      return respostaErro('Calma, sobrevivente. Muitos pedidos seguidos; espere uns segundos.', 429);
    }

    let dados = undefined as T;
    if (opcoes.schema) {
      const corpo = await req.json().catch(() => null);
      const lido = opcoes.schema.safeParse(corpo);
      if (!lido.success) return respostaErro('Dados inválidos.', 400);
      dados = lido.data;
    }

    return await opcoes.executar({ supabase, user, dados });
  } catch (e) {
    console.error(`[acao ${opcoes.nome}]`, e);
    return respostaErro('Algo deu errado. Tente de novo.', 500);
  }
}
