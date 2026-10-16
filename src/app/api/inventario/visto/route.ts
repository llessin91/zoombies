// src/app/api/inventario/visto/route.ts
// Marca que o jogador já viu os itens novos (some a bolinha do menu).
import { NextResponse } from 'next/server';
import { executarAcao, mensagemErroBanco, respostaErro } from '@/lib/api/acao';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  return executarAcao(req, {
    nome: 'inventario_visto',
    executar: async ({ supabase }) => {
      const { error } = await supabase.rpc('marcar_inventario_visto');
      if (error) {
        const e = mensagemErroBanco(error);
        return respostaErro(e.mensagem, e.status);
      }
      return NextResponse.json({ ok: true });
    },
  });
}
