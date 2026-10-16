// src/app/api/abrigo/estado/route.ts
// Estado do abrigo (o banco aplica o catch-up de produção, energia e manutenção antes).
import { NextResponse } from 'next/server';
import { executarAcao, mensagemErroBanco, respostaErro } from '@/lib/api/acao';
import { lerEstadoAbrigo } from '@/lib/game/abrigo';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  return executarAcao(req, {
    nome: 'abrigo_estado',
    limite: { maximo: 15, janelaMs: 10_000 },
    executar: async ({ supabase }) => {
      const { data, error } = await supabase.rpc('estado_abrigo');
      if (error) {
        const e = mensagemErroBanco(error);
        return respostaErro(e.mensagem, e.status);
      }
      return NextResponse.json({ ok: true, estado: lerEstadoAbrigo(data) });
    },
  });
}
