// src/app/api/expedicao/iniciar/route.ts
// Inicia uma expedição. O banco confere stamina, requisitos, arma, consumíveis e carga numa transação.
import { NextResponse } from 'next/server';
import { executarAcao, mensagemErroBanco, respostaErro } from '@/lib/api/acao';
import { iniciarExpedicaoSchema } from '@/lib/validacao/expedicao';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  return executarAcao(req, {
    nome: 'iniciar_expedicao',
    schema: iniciarExpedicaoSchema,
    limite: { maximo: 6, janelaMs: 10_000 },
    executar: async ({ supabase, dados }) => {
      const { data, error } = await supabase.rpc('iniciar_expedicao', {
        p_missao: dados.missao,
        p_arma: dados.arma ?? null,
        p_consumiveis: dados.consumiveis,
      });
      if (error) {
        const e = mensagemErroBanco(error);
        return respostaErro(e.mensagem, e.status);
      }
      return NextResponse.json({ ok: true, id: (data as { id: string }).id });
    },
  });
}
