// src/lib/api/erros.ts
// Traduz erros do banco em mensagens amigáveis, sem vazar detalhes internos.

export interface ErroBanco {
  code?: string;
  message?: string;
}

/** Erros que o próprio jogo levantou (RAISE no SQL) já são amigáveis; o resto vira mensagem genérica */
export function mensagemErroBanco(erro: ErroBanco | null | undefined): { mensagem: string; status: number } {
  if (!erro) return { mensagem: 'Algo deu errado. Tente de novo.', status: 500 };
  if (erro.code === 'P0001' && erro.message) return { mensagem: erro.message, status: 400 };
  if (erro.code === 'PGRST202' || erro.code === '42883') {
    return { mensagem: 'O banco ainda não foi atualizado para esta fase. Veja o README.', status: 500 };
  }
  if (erro.code === '42501') return { mensagem: 'Ação não permitida.', status: 403 };
  return { mensagem: 'Algo deu errado. Tente de novo.', status: 500 };
}
