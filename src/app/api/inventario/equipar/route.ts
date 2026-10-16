// src/app/api/inventario/equipar/route.ts
// Equipar arma no slot certo (principal ou corpo a corpo).
import { NextResponse } from 'next/server';
import { executarAcao, mensagemErroBanco, respostaErro } from '@/lib/api/acao';
import { lerEstadoInventario } from '@/lib/game/inventario';
import { itemSchema } from '@/lib/validacao/inventario';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  return executarAcao(req, {
    nome: 'equipar',
    schema: itemSchema,
    limite: { maximo: 15, janelaMs: 10_000 },
    executar: async ({ supabase, dados }) => {
      const { data, error } = await supabase.rpc('equipar', { p_inventory_id: dados.id });
      if (error) {
        const e = mensagemErroBanco(error);
        return respostaErro(e.mensagem, e.status);
      }
      const r = data as { mensagem: string; inventario: unknown };
      return NextResponse.json({ ok: true, mensagem: r.mensagem, inventario: lerEstadoInventario(r.inventario) });
    },
  });
}
