import type { Metadata } from 'next';
import { PaginaEmConstrucao } from '@/components/game/PaginaEmConstrucao';

export const metadata: Metadata = { title: 'Mapa' };

export default function Pagina() {
  return (
    <PaginaEmConstrucao
      titulo="Mapa"
      fase="4"
      descricao="As quatro regiões, seus locais e requisitos de acesso."
      textoVazio="O mapa está em branco. Alguém precisa explorar."
    />
  );
}
