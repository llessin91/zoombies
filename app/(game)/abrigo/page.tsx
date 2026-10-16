// src/app/(game)/abrigo/page.tsx
// Abrigo: o servidor aplica o catch-up (produção, energia, combustível, manutenção) e monta o estado.

import type { Metadata } from 'next';
import { AvisoCarga } from '@/components/game/AvisoCarga';
import { PaginaBase } from '@/components/game/PaginaBase';
import { TelaAbrigo } from '@/components/game/TelaAbrigo';
import { lerEstadoAbrigo } from '@/lib/game/abrigo';
import { criarClienteServidor } from '@/lib/supabase/server';

export const metadata: Metadata = { title: 'Abrigo' };
export const dynamic = 'force-dynamic';

export default async function Pagina() {
  const supabase = criarClienteServidor();
  const { data, error } = await supabase.rpc('estado_abrigo');
  const lido = error ? null : lerEstadoAbrigo(data);

  return (
    <PaginaBase titulo="Abrigo" descricao="Quatro paredes, um teto e muitos planos. Construa, produza e mantenha a luz acesa.">
      {!lido ? <AvisoCarga faltaAtualizar={['PGRST202', '42883', '42703'].includes(error?.code ?? '')} /> : <TelaAbrigo inicial={lido} />}
    </PaginaBase>
  );
}
