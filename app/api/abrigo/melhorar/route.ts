// src/app/api/abrigo/melhorar/route.ts
// Melhorar uma instalação para o próximo nível.
import { NextResponse } from 'next/server';
import { executarAcao, mensagemErroBanco, respostaErro } from '@/lib/api/acao';
import { lerEstadoAbrigo } from '@/lib/game/abrigo';
import { instalacaoSchema } from '@/lib/validacao/abrigo';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  return executarAcao(req, {
    nome: 'melhorar',
    schema: instalacaoSchema,
    limite: { maximo: 15, janelaMs: 10_000 },
    executar: async ({ supabase, dados }) => {
      const { data, error } = await supabase.rpc('melhorar', { p_id: dados.id });
      if (error) {
        const e = mensagemErroBanco(error);
        return respostaErro(e.mensagem, e.status);
      }
      return NextResponse.json({ ok: true, estado: lerEstadoAbrigo(data) });
    },
  });
}
