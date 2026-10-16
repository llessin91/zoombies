// src/app/(game)/inventario/page.tsx
// Inventário: o servidor monta a lista (com o que pode ser usado, equipado e descartado).

import type { Metadata } from 'next';
import { AvisoCarga } from '@/components/game/AvisoCarga';
import { PaginaBase } from '@/components/game/PaginaBase';
import { TelaInventario } from '@/components/game/TelaInventario';
import { lerEstadoInventario } from '@/lib/game/inventario';
import { criarClienteServidor } from '@/lib/supabase/server';

export const metadata: Metadata = { title: 'Inventário' };
export const dynamic = 'force-dynamic';

export default async function Pagina() {
  const supabase = criarClienteServidor();
  const { data, error } = await supabase.rpc('estado_inventario');

  return (
    <PaginaBase titulo="Inventário" descricao="Tudo o que você carrega. Arrume antes que a mochila arrume você.">
      {error ? (
        <AvisoCarga faltaAtualizar={['PGRST202', '42883'].includes(error.code ?? '')} />
      ) : (
        <TelaInventario inicial={lerEstadoInventario(data)} />
      )}
    </PaginaBase>
  );
}
