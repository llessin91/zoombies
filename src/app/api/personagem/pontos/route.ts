// src/app/api/personagem/pontos/route.ts
// Distribui pontos de atributo. Recebe quanto SOMAR em cada um; o banco confere tudo e trava a linha.
import { NextResponse } from 'next/server';
import { executarAcao, mensagemErroBanco, respostaErro } from '@/lib/api/acao';
import { lerEstadoPersonagem } from '@/lib/game/personagem';
import { distribuirPontosSchema } from '@/lib/validacao/personagem';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  return executarAcao(req, {
    nome: 'distribuir_pontos',
    schema: distribuirPontosSchema,
    limite: { maximo: 10, janelaMs: 10_000 },
    executar: async ({ supabase, dados }) => {
      const { data, error } = await supabase.rpc('distribuir_pontos', {
        p_forca: dados.forca,
        p_agilidade: dados.agilidade,
        p_percepcao: dados.percepcao,
        p_medicina: dados.medicina,
        p_engenharia: dados.engenharia,
        p_lideranca: dados.lideranca,
      });
      if (error) {
        const e = mensagemErroBanco(error);
        return respostaErro(e.mensagem, e.status);
      }
      return NextResponse.json({ ok: true, estado: lerEstadoPersonagem(data) });
    },
  });
}
