import type { Metadata } from 'next';
import { PaginaEmConstrucao } from '@/components/game/PaginaEmConstrucao';

export const metadata: Metadata = { title: 'Tutorial' };

export default function Pagina() {
  return (
    <PaginaEmConstrucao
      titulo="Tutorial"
      fase="11"
      descricao="Cena inicial, escolha do abrigo e primeira expedição guiada."
      textoVazio="O fim do mundo ainda não começou oficialmente."
    />
  );
}
