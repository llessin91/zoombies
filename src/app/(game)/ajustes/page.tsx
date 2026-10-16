import type { Metadata } from 'next';
import { PaginaEmConstrucao } from '@/components/game/PaginaEmConstrucao';

export const metadata: Metadata = { title: 'Ajustes' };

export default function Pagina() {
  return (
    <PaginaEmConstrucao
      titulo="Ajustes"
      fase="12"
      descricao="Reduzir animações, som, tamanho do texto, alto contraste, instalar app e conta."
      textoVazio="Nada para ajustar ainda."
    />
  );
}
