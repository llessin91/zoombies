// src/app/api/personagem/criar/route.ts
// Cria o personagem com os pontos iniciais. As regras (12 pontos, 1 a 3 em cada) são checadas no banco.
import { NextResponse } from 'next/server';
import { executarAcao, mensagemErroBanco, respostaErro } from '@/lib/api/acao';
import { lerEstadoPersonagem } from '@/lib/game/personagem';
import { criarPersonagemSchema } from '@/lib/validacao/personagem';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  return executarAcao(req, {
    nome: 'criar_personagem',
    schema: criarPersonagemSchema,
    limite: { maximo: 5, janelaMs: 10_000 },
    executar: async ({ supabase, dados }) => {
      const { data, error } = await supabase.rpc('criar_personagem', {
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
