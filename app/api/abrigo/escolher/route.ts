// src/app/api/abrigo/escolher/route.ts
// Escolha do abrigo inicial (uma vez só).
import { NextResponse } from 'next/server';
import { executarAcao, mensagemErroBanco, respostaErro } from '@/lib/api/acao';
import { lerEstadoAbrigo } from '@/lib/game/abrigo';
import { escolherAbrigoSchema } from '@/lib/validacao/abrigo';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  return executarAcao(req, {
    nome: 'escolher_abrigo',
    schema: escolherAbrigoSchema,
    limite: { maximo: 15, janelaMs: 10_000 },
    executar: async ({ supabase, dados }) => {
      const { data, error } = await supabase.rpc('escolher_abrigo_inicial', { p_slug: dados.slug });
      if (error) {
        const e = mensagemErroBanco(error);
        return respostaErro(e.mensagem, e.status);
      }
      return NextResponse.json({ ok: true, estado: lerEstadoAbrigo(data) });
    },
  });
}
