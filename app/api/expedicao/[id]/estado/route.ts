// src/app/api/expedicao/[id]/estado/route.ts
// Estado atual (o banco abre o evento na hora certa e aplica a opção cautelosa após 24 h).
import { executarAcao, respostaErro } from '@/lib/api/acao';
import { idValido, responderEstado } from '@/lib/api/expedicao';

export const dynamic = 'force-dynamic';

export async function POST(req: Request, { params }: { params: { id: string } }) {
  if (!idValido(params.id)) return respostaErro('Expedição não encontrada.', 404);
  return executarAcao(req, {
    nome: 'estado_expedicao',
    limite: { maximo: 40, janelaMs: 60_000 },
    executar: async ({ supabase }) => {
      const { data, error } = await supabase.rpc('estado_expedicao', { p_id: params.id });
      return responderEstado(data, error);
    },
  });
}
