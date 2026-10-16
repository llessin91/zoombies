import type { Metadata } from 'next';
import { PaginaEmConstrucao } from '@/components/game/PaginaEmConstrucao';

export const metadata: Metadata = { title: 'Fabricação' };

export default function Pagina() {
  return (
    <PaginaEmConstrucao
      titulo="Fabricação"
      fase="9"
      descricao="Receitas, reparos e fila de fabricação."
      textoVazio="Sem receitas por enquanto. Falta um manual e sobra improviso."
    />
  );
}
