// src/components/game/AvisoCarga.tsx
// Aviso dentro da página quando os dados do mundo não carregam.

import { DatabaseZap } from 'lucide-react';

export function AvisoCarga({ faltaAtualizar }: { faltaAtualizar: boolean }) {
  return (
    <div role="alert" className="flex flex-col items-center gap-3 rounded-lg border border-acento-ambar/50 bg-fundo-1 px-4 py-10 text-center">
      <DatabaseZap className="h-8 w-8 text-acento-ambar" aria-hidden />
      {faltaAtualizar ? (
        <p className="max-w-md text-sm">
          O banco ainda não tem as missões desta fase. No Supabase, abra o <strong>SQL Editor</strong>, cole o arquivo{' '}
          <code className="font-mono">supabase/atualizacao_fase5.sql</code> e clique em <strong>Run</strong>. Depois recarregue.
        </p>
      ) : (
        <p className="max-w-md text-sm">Não foi possível carregar o mundo agora. Recarregue a página em alguns segundos.</p>
      )}
    </div>
  );
}
