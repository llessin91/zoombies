import type { Metadata } from 'next';
import { FormularioLogin } from '@/components/auth/FormularioLogin';

export const metadata: Metadata = { title: 'Entrar' };

export default function LoginPage({ searchParams }: { searchParams: { erro?: string } }) {
  const aviso = searchParams.erro === 'link' ? 'O link expirou ou já foi usado. Peça um novo.' : undefined;
  return <FormularioLogin aviso={aviso} />;
}
