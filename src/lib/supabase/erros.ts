import type { AuthError } from '@supabase/supabase-js';

// Traduz erros do Supabase Auth para mensagens simples, sem vazar detalhes internos
export function mensagemErroAuth(erro: AuthError): string {
  switch (erro.code) {
    case 'invalid_credentials':
      return 'E-mail ou senha incorretos.';
    case 'email_not_confirmed':
      return 'Confirme seu e-mail antes de entrar. Procure o link na sua caixa de entrada.';
    case 'user_already_exists':
    case 'email_exists':
      return 'Este e-mail já tem uma conta. Tente entrar.';
    case 'weak_password':
      return 'Senha fraca demais. Use uma senha mais longa e variada.';
    case 'over_email_send_rate_limit':
    case 'over_request_rate_limit':
      return 'Muitas tentativas seguidas. Espere alguns minutos e tente de novo.';
    default:
      if (erro.message.includes('Database error saving new user')) {
        return 'Não foi possível criar a conta. O nome de sobrevivente pode já estar em uso.';
      }
      return 'Algo deu errado. Tente de novo em instantes.';
  }
}

export function ehLimiteDeEnvio(erro: AuthError): boolean {
  return erro.code === 'over_email_send_rate_limit' || erro.code === 'over_request_rate_limit';
}
