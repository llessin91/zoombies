import type { Metadata } from 'next';
import { PaginaEmConstrucao } from '@/components/game/PaginaEmConstrucao';

export const metadata: Metadata = { title: 'Recrutas' };

export default function Pagina() {
  return (
    <PaginaEmConstrucao
      titulo="Recrutas"
      fase="8"
      descricao="Sobreviventes que moram no seu abrigo, consumo e moral."
      textoVazio="Ninguém por aqui além de você. Silêncio demais."
    />
  );
}
