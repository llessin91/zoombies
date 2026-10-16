import type { Metadata } from 'next';
import { PaginaEmConstrucao } from '@/components/game/PaginaEmConstrucao';

export const metadata: Metadata = { title: 'Inventário' };

export default function Pagina() {
  return (
    <PaginaEmConstrucao
      titulo="Inventário"
      fase="6"
      descricao="Recursos, consumíveis, armas e itens-chave."
      textoVazio="Mochila vazia. Até as moscas desistiram."
    />
  );
}
