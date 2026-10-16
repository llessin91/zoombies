// src/app/api/expedicao/[id]/loot/route.ts
// "O que levar": quando o saque passa da capacidade, o jogador escolhe. O banco confere peso e quantidades.
import { executarAcao, respostaErro } from '@/lib/api/acao';
import { idValido, responderEstado } from '@/lib/api/expedicao';
import { confirmarLootSchema } from '@/lib/validacao/expedicao';

export const dynamic = 'force-dynamic';

export async function POST(req: Request, { params }: { params: { id: string } }) {
  if (!idValido(params.id)) return respostaErro('Expedição não encontrada.', 404);
  return executarAcao(req, {
    nome: 'confirmar_loot',
    schema: confirmarLootSchema,
    limite: { maximo: 6, janelaMs: 10_000 },
    executar: async ({ supabase, dados }) => {
      const { data, error } = await supabase.rpc('confirmar_loot', { p_id: params.id, p_escolha: dados.escolha });
      return responderEstado(data, error);
    },
  });
}
