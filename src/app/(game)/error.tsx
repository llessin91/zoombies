'use client';

import { PaginaBase } from '@/components/game/PaginaBase';
import { EstadoErro } from '@/components/ui/Estados';

export default function Erro({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <PaginaBase titulo="Algo deu errado">
      <EstadoErro mensagem="Um zumbi mordeu o cabo. Tente de novo." aoTentarNovamente={reset} />
    </PaginaBase>
  );
}
