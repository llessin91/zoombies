import type { Metadata } from 'next';
import { PaginaEmConstrucao } from '@/components/game/PaginaEmConstrucao';

export const metadata: Metadata = { title: 'Missões' };

export default function Pagina() {
  return (
    <PaginaEmConstrucao
      titulo="Missões"
      fase="4"
      descricao="Lista de missões com filtros, preparação e início de expedição."
      textoVazio="Sem missões no radar. O mundo anda calmo demais."
    />
  );
}
