import Link from 'next/link';
import type { ReactNode } from 'react';
import { ChevronRight } from 'lucide-react';

export interface Migalha {
  rotulo: string;
  href?: string;
}

interface PaginaBaseProps {
  titulo: string;
  descricao?: string;
  migalhas?: Migalha[];
  acoes?: ReactNode;
  children: ReactNode;
}

export function PaginaBase({ titulo, descricao, migalhas, acoes, children }: PaginaBaseProps) {
  const trilha: Migalha[] =
    migalhas ?? (titulo === 'Início' ? [] : [{ rotulo: 'Início', href: '/inicio' }, { rotulo: titulo }]);

  return (
    <div className="space-y-6">
      <div>
        {trilha.length > 0 && (
          <nav aria-label="Você está em" className="mb-2">
            <ol className="flex flex-wrap items-center gap-1 text-xs text-texto-suave">
              {trilha.map((m, i) => (
                <li key={m.rotulo} className="flex items-center gap-1">
                  {i > 0 && <ChevronRight className="h-3 w-3" aria-hidden />}
                  {m.href ? (
                    <Link href={m.href} className="hover:text-texto hover:underline">
                      {m.rotulo}
                    </Link>
                  ) : (
                    <span aria-current="page" className="text-texto">
                      {m.rotulo}
                    </span>
                  )}
                </li>
              ))}
            </ol>
          </nav>
        )}
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <h1 className="font-titulo text-4xl tracking-wide">{titulo}</h1>
            {descricao && <p className="mt-1 max-w-2xl text-sm text-texto-suave">{descricao}</p>}
          </div>
          {acoes}
        </div>
      </div>
      {children}
    </div>
  );
}
