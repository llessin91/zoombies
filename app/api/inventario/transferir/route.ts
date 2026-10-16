// src/app/api/inventario/transferir/route.ts
// Mover itens entre a mochila e o depósito do abrigo.
import { NextResponse } from 'next/server';
import { executarAcao, mensagemErroBanco, respostaErro } from '@/lib/api/acao';
import { lerEstadoInventario } from '@/lib/game/inventario';
import { transferirSchema } from '@/lib/validacao/abrigo';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  return executarAcao(req, {
    nome: 'transferir_item',
    schema: transferirSchema,
    limite: { maximo: 20, janelaMs: 10_000 },
    executar: async ({ supabase, dados }) => {
      const { data, error } = await supabase.rpc('transferir_item', {
        p_inventory_id: dados.id,
        p_qtd: dados.qtd,
        p_destino: dados.destino,
      });
      if (error) {
        const e = mensagemErroBanco(error);
        return respostaErro(e.mensagem, e.status);
      }
      const r = data as { mensagem: string; inventario: unknown };
      return NextResponse.json({ ok: true, mensagem: r.mensagem, inventario: lerEstadoInventario(r.inventario) });
    },
  });
}
