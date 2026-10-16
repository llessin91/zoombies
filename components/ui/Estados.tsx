import type { ReactNode } from 'react';
import { AlertOctagon, Inbox } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Botao } from './Botao';

interface EstadoVazioProps {
  texto?: string;
  detalhe?: string;
  icone?: ReactNode;
  compacto?: boolean;
}

export function EstadoVazio({ texto = 'Nada aqui. Nem os zumbis passaram.', detalhe, icone, compacto = false }: EstadoVazioProps) {
  return (
    <div className={cn('flex flex-col items-center gap-2 text-center text-texto-suave', compacto ? 'py-4' : 'py-10')}>
      {icone ?? <Inbox className="h-8 w-8" aria-hidden />}
      <p className="text-sm text-texto">{texto}</p>
      {detalhe && <p className="max-w-sm text-xs">{detalhe}</p>}
    </div>
  );
}

interface EstadoErroProps {
  mensagem: string;
  aoTentarNovamente: () => void;
}

export function EstadoErro({ mensagem, aoTentarNovamente }: EstadoErroProps) {
  return (
    <div role="alert" className="flex flex-col items-center gap-3 py-10 text-center">
      <AlertOctagon className="h-8 w-8 text-acento-vermelho" aria-hidden />
      <p className="text-sm">{mensagem}</p>
      <Botao variante="secundario" onClick={aoTentarNovamente}>
        Tentar novamente
      </Botao>
    </div>
  );
}
