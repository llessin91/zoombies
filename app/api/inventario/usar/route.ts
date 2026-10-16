// src/app/api/inventario/usar/route.ts
// Usar 1 unidade de um consumível (stamina ou ferimentos). O banco confere tudo.
import { NextResponse } from 'next/server';
import { executarAcao, mensagemErroBanco, respostaErro } from '@/lib/api/acao';
import { lerEstadoInventario } from '@/lib/game/inventario';
import { itemSchema } from '@/lib/validacao/inventario';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  return executarAcao(req, {
    nome: 'usar_item',
    schema: itemSchema,
    limite: { maximo: 15, janelaMs: 10_000 },
    executar: async ({ supabase, dados }) => {
      const { data, error } = await supabase.rpc('usar_item', { p_inventory_id: dados.id });
      if (error) {
        const e = mensagemErroBanco(error);
        return respostaErro(e.mensagem, e.status);
      }
      const r = data as { mensagem: string; inventario: unknown };
      return NextResponse.json({ ok: true, mensagem: r.mensagem, inventario: lerEstadoInventario(r.inventario) });
    },
  });
}
