import type { Metadata } from 'next';
import { FormularioCadastro } from '@/components/auth/FormularioCadastro';

export const metadata: Metadata = { title: 'Criar conta' };

export default function CadastroPage() {
  return <FormularioCadastro />;
}
