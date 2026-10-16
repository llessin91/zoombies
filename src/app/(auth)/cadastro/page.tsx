import Link from 'next/link';
import type { Metadata } from 'next';
import { Cartao } from '@/components/ui/Cartao';

export const metadata: Metadata = { title: 'Criar conta' };

export default function CadastroPage() {
  return (
    <Cartao titulo="Criar conta" subtitulo="Placeholder da Fase 1">
      <p className="text-sm text-texto-suave">A tela de cadastro chega na Fase 2 (Supabase e autenticação).</p>
      <Link href="/inicio" className="mt-4 inline-block text-sm text-acento-verde underline">
        Ver o jogo por enquanto
      </Link>
    </Cartao>
  );
}
