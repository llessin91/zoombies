// src/app/api/personagem/estado/route.ts
// Sincroniza: o banco aplica o catch-up (stamina etc.) e devolve o estado atual.
import { NextResponse } from 'next/server';
import { executarAcao, mensagemErroBanco, respostaErro } from '@/lib/api/acao';
import { lerEstadoPersonagem } from '@/lib/game/personagem';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  return executarAcao(req, {
    nome: 'sincronizar',
    limite: { maximo: 30, janelaMs: 60_000 },
    executar: async ({ supabase }) => {
      const { data, error } = await supabase.rpc('sincronizar_estado');
      if (error) {
        const e = mensagemErroBanco(error);
        return respostaErro(e.mensagem, e.status);
      }
      return NextResponse.json({ ok: true, estado: lerEstadoPersonagem(data) });
    },
  });
}
