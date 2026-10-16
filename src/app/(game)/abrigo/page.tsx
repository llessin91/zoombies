import type { Metadata } from 'next';
import { PaginaEmConstrucao } from '@/components/game/PaginaEmConstrucao';

export const metadata: Metadata = { title: 'Abrigo' };

export default function Pagina() {
  return (
    <PaginaEmConstrucao
      titulo="Abrigo"
      fase="7"
      descricao="Instalações, recursos, energia, produção e alertas."
      textoVazio="Nenhum abrigo escolhido ainda."
    />
  );
}
