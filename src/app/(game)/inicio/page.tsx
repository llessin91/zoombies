import type { Metadata } from 'next';
import { PaginaEmConstrucao } from '@/components/game/PaginaEmConstrucao';

export const metadata: Metadata = { title: 'Início' };

export default function Pagina() {
  return (
    <PaginaEmConstrucao
      titulo="Início"
      fase="3 em diante"
      descricao="Painel com personagem, abrigo, expedição em andamento, produção pronta e últimos acontecimentos."
      textoVazio="Nada aqui. Nem os zumbis passaram."
    />
  );
}
