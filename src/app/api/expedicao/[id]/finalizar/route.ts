// src/app/api/expedicao/[id]/finalizar/route.ts
// Termina a expedição e calcula o resultado. Seguro contra cliques repetidos (devolve o mesmo resultado).
import { executarAcao, respostaErro } from '@/lib/api/acao';
import { idValido, responderEstado } from '@/lib/api/expedicao';
import { finalizarExpedicaoSchema } from '@/lib/validacao/expedicao';

export const dynamic = 'force-dynamic';

export async function POST(req: Request, { params }: { params: { id: string } }) {
  if (!idValido(params.id)) return respostaErro('Expedição não encontrada.', 404);
  return executarAcao(req, {
    nome: 'finalizar_expedicao',
    schema: finalizarExpedicaoSchema,
    limite: { maximo: 10, janelaMs: 10_000 },
    executar: async ({ supabase, dados }) => {
      const { data, error } = await supabase.rpc('finalizar_expedicao', { p_id: params.id, p_pular: dados.pular });
      return responderEstado(data, error);
    },
  });
}
