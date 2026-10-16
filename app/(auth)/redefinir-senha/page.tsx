import type { Metadata } from 'next';
import { FormularioRedefinirSenha } from '@/components/auth/FormularioRedefinirSenha';

export const metadata: Metadata = { title: 'Nova senha' };

// Exige login: o jogador chega aqui pelo link do e-mail de recuperação (middleware protege a rota)
export default function RedefinirSenhaPage() {
  return <FormularioRedefinirSenha />;
}
