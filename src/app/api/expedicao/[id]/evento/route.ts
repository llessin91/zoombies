// src/app/api/expedicao/[id]/evento/route.ts
// Escolher uma opção do evento. Requisitos e custos são conferidos no banco.
import { executarAcao, respostaErro } from '@/lib/api/acao';
import { idValido, responderEstado } from '@/lib/api/expedicao';
import { resolverEventoSchema } from '@/lib/validacao/expedicao';

export const dynamic = 'force-dynamic';

export async function POST(req: Request, { params }: { params: { id: string } }) {
  if (!idValido(params.id)) return respostaErro('Expedição não encontrada.', 404);
  return executarAcao(req, {
    nome: 'resolver_evento',
    schema: resolverEventoSchema,
    limite: { maximo: 6, janelaMs: 10_000 },
    executar: async ({ supabase, dados }) => {
      const { data, error } = await supabase.rpc('resolver_evento', { p_id: params.id, p_opcao: dados.opcao });
      return responderEstado(data, error);
    },
  });
}
