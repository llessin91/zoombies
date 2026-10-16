import { Cartao } from '@/components/ui/Cartao';
import { EstadoVazio } from '@/components/ui/Estados';
import { Selo } from '@/components/ui/Selo';
import { SkeletonLista } from '@/components/ui/Skeleton';
import { PaginaBase } from './PaginaBase';

interface Props {
  titulo: string;
  descricao: string;
  /** Fase em que esta tela fica pronta */
  fase: number | string;
  textoVazio: string;
}

// Tela provisória da Fase 1: título, skeleton e estado vazio temático
export function PaginaEmConstrucao({ titulo, descricao, fase, textoVazio }: Props) {
  return (
    <PaginaBase titulo={titulo} descricao={descricao} acoes={<Selo tom="ambar">Fase {fase}</Selo>}>
      <SkeletonLista quantidade={3} />
      <Cartao>
        <EstadoVazio texto={textoVazio} detalhe={`Esta tela ganha vida na Fase ${fase}.`} />
      </Cartao>
    </PaginaBase>
  );
}
