// src/app/api/inventario/descartar/route.ts
// Descartar itens (itens-chave e armas equipadas ficam protegidos).
import { NextResponse } from 'next/server';
import { executarAcao, mensagemErroBanco, respostaErro } from '@/lib/api/acao';
import { lerEstadoInventario } from '@/lib/game/inventario';
import { descartarSchema } from '@/lib/validacao/inventario';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  return executarAcao(req, {
    nome: 'descartar_item',
    schema: descartarSchema,
    limite: { maximo: 15, janelaMs: 10_000 },
    executar: async ({ supabase, dados }) => {
      const { data, error } = await supabase.rpc('descartar_item', { p_inventory_id: dados.id, p_qtd: dados.qtd });
      if (error) {
        const e = mensagemErroBanco(error);
        return respostaErro(e.mensagem, e.status);
      }
      const r = data as { mensagem: string; inventario: unknown };
      return NextResponse.json({ ok: true, mensagem: r.mensagem, inventario: lerEstadoInventario(r.inventario) });
    },
  });
}
