// src/app/api/abrigo/reciclar/route.ts
// Oficina de reciclagem: sucata em metal ou componentes.
import { NextResponse } from 'next/server';
import { executarAcao, mensagemErroBanco, respostaErro } from '@/lib/api/acao';
import { lerEstadoAbrigo } from '@/lib/game/abrigo';
import { reciclarSchema } from '@/lib/validacao/abrigo';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  return executarAcao(req, {
    nome: 'reciclar',
    schema: reciclarSchema,
    limite: { maximo: 15, janelaMs: 10_000 },
    executar: async ({ supabase, dados }) => {
      const { data, error } = await supabase.rpc('reciclar', { p_produto: dados.produto, p_vezes: dados.vezes });
      if (error) {
        const e = mensagemErroBanco(error);
        return respostaErro(e.mensagem, e.status);
      }
      return NextResponse.json({ ok: true, estado: lerEstadoAbrigo(data) });
    },
  });
}
