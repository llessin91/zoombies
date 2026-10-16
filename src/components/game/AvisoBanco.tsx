// src/components/game/AvisoBanco.tsx
// Tela mostrada quando o banco não responde como esperado (ex.: faltou rodar o SQL da fase).

import { DatabaseZap } from 'lucide-react';

export function AvisoBanco({ faltaAtualizar }: { faltaAtualizar: boolean }) {
  return (
    <main className="relative z-10 mx-auto flex min-h-dvh max-w-lg flex-col items-center justify-center gap-4 px-4 text-center">
      <DatabaseZap className="h-10 w-10 text-acento-ambar" aria-hidden />
      <h1 className="font-titulo text-3xl tracking-wide">
        {faltaAtualizar ? 'Falta atualizar o banco' : 'O banco não respondeu'}
      </h1>
      {faltaAtualizar ? (
        <p className="text-sm text-texto-suave">
          O site está numa fase mais nova que o Supabase. Abra o <strong className="text-texto">SQL Editor</strong> do
          Supabase, cole o arquivo <code className="font-mono text-texto">supabase/atualizacao_fase6.sql</code> e clique em{' '}
          <strong className="text-texto">Run</strong>. Depois recarregue esta página.
        </p>
      ) : (
        <p className="text-sm text-texto-suave">Pode ser instabilidade momentânea. Espere alguns segundos e recarregue a página.</p>
      )}
    </main>
  );
}
