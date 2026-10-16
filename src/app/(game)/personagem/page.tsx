import type { Metadata } from 'next';
import { PaginaEmConstrucao } from '@/components/game/PaginaEmConstrucao';

export const metadata: Metadata = { title: 'Personagem' };

export default function Pagina() {
  return (
    <PaginaEmConstrucao
      titulo="Personagem"
      fase="3"
      descricao="Atributos, XP, níveis, moral, equipamento e estatísticas."
      textoVazio="Nenhum sobrevivente por aqui ainda."
    />
  );
}
