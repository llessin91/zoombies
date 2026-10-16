// src/app/api/inventario/desequipar/route.ts
// Tirar a arma de um slot.
import { NextResponse } from 'next/server';
import { executarAcao, mensagemErroBanco, respostaErro } from '@/lib/api/acao';
import { lerEstadoInventario } from '@/lib/game/inventario';
import { desequiparSchema } from '@/lib/validacao/inventario';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  return executarAcao(req, {
    nome: 'desequipar',
    schema: desequiparSchema,
    limite: { maximo: 15, janelaMs: 10_000 },
    executar: async ({ supabase, dados }) => {
      const { data, error } = await supabase.rpc('desequipar', { p_slot: dados.slot });
      if (error) {
        const e = mensagemErroBanco(error);
        return respostaErro(e.mensagem, e.status);
      }
      const r = data as { mensagem: string; inventario: unknown };
      return NextResponse.json({ ok: true, mensagem: r.mensagem, inventario: lerEstadoInventario(r.inventario) });
    },
  });
}
