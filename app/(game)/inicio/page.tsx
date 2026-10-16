// src/app/(game)/inicio/page.tsx
// Painel inicial: personagem, relógio do jogo, atalhos, abrigo, expedição, produção pronta e acontecimentos.

import type { Metadata } from 'next';
import Link from 'next/link';
import { Hammer, Hourglass, Package, Target, Warehouse } from 'lucide-react';
import { CartaoExpedicaoAtiva } from '@/components/game/CartaoExpedicaoAtiva';
import { CartaoPersonagem } from '@/components/game/CartaoPersonagem';
import { FeedAcontecimentos, type Acontecimento } from '@/components/game/FeedAcontecimentos';
import { PaginaBase } from '@/components/game/PaginaBase';
import { RelogioJogo } from '@/components/game/RelogioJogo';
import { CartaoProducaoPronta, CartaoResumoAbrigo } from '@/components/game/ResumoAbrigo';
import { Cartao } from '@/components/ui/Cartao';
import { criarClienteServidor } from '@/lib/supabase/server';

export const metadata: Metadata = { title: 'Início' };

const ATALHOS = [
  { href: '/missoes', rotulo: 'Nova missão', icone: Target },
  { href: '/abrigo', rotulo: 'Ir ao abrigo', icone: Warehouse },
  { href: '/fabricacao', rotulo: 'Fabricar', icone: Hammer },
];

export default async function Pagina() {
  const supabase = criarClienteServidor();
  // RLS garante que só vêm os registros do próprio jogador
  const { data, error } = await supabase
    .from('game_log')
    .select('id, tipo, texto, criado_em')
    .order('criado_em', { ascending: false })
    .limit(10);
  const acontecimentos = (data ?? []) as Acontecimento[];

  return (
    <PaginaBase titulo="Início" acoes={<RelogioJogo className="rounded-md border border-borda bg-fundo-1 px-3 py-2" />}>
      <div className="grid gap-4 lg:grid-cols-2">
        <CartaoPersonagem />

        <div className="space-y-4">
          <Cartao titulo="Atalhos" indice={1}>
            <ul className="grid grid-cols-3 gap-2">
              {ATALHOS.map(({ href, rotulo, icone: Icone }) => (
                <li key={href}>
                  <Link
                    href={href}
                    className="flex min-h-[72px] flex-col items-center justify-center gap-1 rounded-md border border-borda text-center text-xs hover:border-acento-verde/60 hover:bg-fundo-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde"
                  >
                    <Icone className="h-5 w-5 text-acento-verde" aria-hidden />
                    {rotulo}
                  </Link>
                </li>
              ))}
            </ul>
          </Cartao>

          <Cartao titulo="Abrigo" icone={<Warehouse className="h-5 w-5 text-texto-suave" aria-hidden />} indice={2}>
            <CartaoResumoAbrigo />
          </Cartao>
        </div>

        <Cartao titulo="Expedição em andamento" icone={<Hourglass className="h-5 w-5 text-texto-suave" aria-hidden />} indice={3}>
          <CartaoExpedicaoAtiva />
        </Cartao>

        <Cartao titulo="Produção pronta" icone={<Package className="h-5 w-5 text-texto-suave" aria-hidden />} indice={4}>
          <CartaoProducaoPronta />
        </Cartao>

        <Cartao titulo="Últimos acontecimentos" indice={5} className="lg:col-span-2">
          {error ? (
            <p role="alert" className="text-sm text-acento-vermelho">
              Não foi possível carregar os acontecimentos. Recarregue a página.
            </p>
          ) : (
            <FeedAcontecimentos itens={acontecimentos} />
          )}
        </Cartao>
      </div>
    </PaginaBase>
  );
}
