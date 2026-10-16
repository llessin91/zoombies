// src/app/api/personagem/nivel-visto/route.ts
// Marca que a animação de "subiu de nível" já foi mostrada.
import { NextResponse } from 'next/server';
import { executarAcao, mensagemErroBanco, respostaErro } from '@/lib/api/acao';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  return executarAcao(req, {
    nome: 'nivel_visto',
    executar: async ({ supabase }) => {
      const { error } = await supabase.rpc('marcar_nivel_visto');
      if (error) {
        const e = mensagemErroBanco(error);
        return respostaErro(e.mensagem, e.status);
      }
      return NextResponse.json({ ok: true });
    },
  });
}
