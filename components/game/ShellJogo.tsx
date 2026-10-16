'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useState } from 'react';
import { AlertTriangle, Droplets, Fuel, Hammer, HeartPulse, LogOut, MoreHorizontal, PackageOpen, Plug, Star, Wheat } from 'lucide-react';
import { ITENS_MAIS, ITENS_MOBILE, ITENS_NAVEGACAO } from '@/lib/navegacao';
import { Barra } from '@/components/ui/Barra';
import { Botao } from '@/components/ui/Botao';
import { Cartao } from '@/components/ui/Cartao';
import { EstadoVazio } from '@/components/ui/Estados';
import { Modal } from '@/components/ui/Modal';
import { criarClienteNavegador } from '@/lib/supabase/client';
import { cn } from '@/lib/utils';
import { BarraStamina } from './BarraStamina';
import { useEstadoJogo } from './EstadoJogo';
import { RelogioJogo } from './RelogioJogo';


function Bolinha({ ativa }: { ativa?: boolean }) {
  if (!ativa) return null;
  return <span aria-label="Novidade" className="absolute right-2 top-2 h-2.5 w-2.5 rounded-full bg-acento-vermelho ring-2 ring-fundo-1" />;
}

export function ShellJogo({ children }: { children: React.ReactNode }) {
  const caminho = usePathname();
  const router = useRouter();
  const [saindo, setSaindo] = useState(false);
  const [maisAberto, setMaisAberto] = useState(false);
  const ativo = (href: string) => caminho === href || caminho.startsWith(`${href}/`);
  const { estado } = useEstadoJogo();
  const nomeSobrevivente = estado.nome;

  // Bolinhas de notificação por rota: pontos para distribuir (Personagem) e expedição em andamento ou com resultado (Missões).
  // Abrigo: produção pronta ou alerta. (Fabricação pronta e recrutas entram nas próximas fases.)
  const ab = estado.abrigo;
  const indicadores: Record<string, boolean> = {
    '/personagem': estado.pontos_disponiveis > 0,
    '/missoes': Boolean(estado.expedicao),
    '/inventario': estado.itens_novos,
    '/abrigo': Boolean(ab && (ab.producao_pronta > 0 || ab.alertas > 0)),
  };
  const recursos = [
    { rotulo: 'Comida', icone: Wheat, valor: ab ? String(ab.comida) : '—', baixo: ab ? ab.comida === 0 : false },
    { rotulo: 'Água', icone: Droplets, valor: ab ? String(ab.agua) : '—', baixo: ab ? ab.agua === 0 : false },
    { rotulo: 'Combustível', icone: Fuel, valor: ab ? String(ab.combustivel) : '—', baixo: false },
    {
      rotulo: 'Energia',
      icone: Plug,
      valor: !ab ? '—' : !ab.tem_energia ? 'sem gerador' : ab.energia_ok ? 'ok' : 'sem energia',
      baixo: Boolean(ab && ab.tem_energia && !ab.energia_ok),
    },
  ];
  const alertasAbrigo = !ab
    ? []
    : [
        ab.producao_pronta > 0 && { icone: PackageOpen, texto: `Produção pronta em ${ab.producao_pronta} instalação(ões).`, tom: 'text-acento-verde' },
        ab.construindo > 0 && { icone: Hammer, texto: `${ab.construindo} obra(s) em andamento.`, tom: 'text-acento-ambar' },
        ab.alertas > 0 && { icone: AlertTriangle, texto: 'Instalação parada ou sem energia.', tom: 'text-acento-vermelho' },
        ab.comida === 0 && { icone: Wheat, texto: 'Sem comida no depósito.', tom: 'text-acento-vermelho' },
        ab.agua === 0 && { icone: Droplets, texto: 'Sem água no depósito.', tom: 'text-acento-vermelho' },
      ].filter((a): a is { icone: typeof Wheat; texto: string; tom: string } => Boolean(a));
  const maisAtivo = ITENS_MAIS.some((i) => ativo(i.href));

  async function sair() {
    setSaindo(true);
    try {
      await criarClienteNavegador().auth.signOut();
    } finally {
      router.replace('/login');
      router.refresh();
    }
  }

  return (
    <div className="relative z-10 flex min-h-dvh flex-col">
      <a
        href="#conteudo"
        className="sr-only focus:not-sr-only focus:absolute focus:left-2 focus:top-2 focus:z-50 focus:rounded focus:bg-fundo-2 focus:px-3 focus:py-2"
      >
        Pular para o conteúdo
      </a>

      {/* Barra superior */}
      <header className="sticky top-0 z-30 border-b border-borda bg-fundo-1/95 backdrop-blur">
        <div className="flex h-14 items-center gap-2 px-3 sm:gap-3 sm:px-4 lg:gap-6 lg:px-6">
          <Link href="/inicio" className="shrink-0 font-titulo text-lg tracking-[0.12em] text-acento-verde sm:text-xl sm:tracking-[0.2em]">
            ZOMBIES
          </Link>

          <div className="hidden shrink-0 items-center gap-2 md:flex">
            <Star className="h-4 w-4 shrink-0 text-acento-roxo" aria-hidden />
            <span className="whitespace-nowrap text-sm">
              Nível <span className="font-mono">{estado.nivel}</span>
            </span>
            <Barra valor={estado.xp} max={estado.xp_proximo} tom="roxo" altura="sm" rotulo="Experiência" ocultarRotulo className="w-24 shrink-0 xl:w-32" />
            <span className="hidden whitespace-nowrap font-mono text-xs text-texto-suave xl:inline">
              {estado.xp}/{estado.xp_proximo}
            </span>
          </div>

          <div className="ml-auto flex min-w-0 items-center gap-2.5 md:gap-4">
            <BarraStamina compacta />
            <div className="flex shrink-0 items-center gap-1.5 md:gap-2">
              <HeartPulse className="h-4 w-4 shrink-0 text-acento-vermelho" aria-hidden />
              <Barra valor={estado.moral} max={100} tom="moral" altura="sm" rotulo="Moral" ocultarRotulo className="w-8 shrink-0 sm:w-12 md:w-20" />
              <span className="font-mono text-xs">{estado.moral}</span>
            </div>
            <RelogioJogo className="hidden whitespace-nowrap md:flex" />
            <Botao
              variante="fantasma"
              carregando={saindo}
              onClick={sair}
              icone={<LogOut className="h-4 w-4" aria-hidden />}
              className="hidden lg:inline-flex"
            >
              Sair
            </Botao>
          </div>
        </div>
      </header>

      <div className="flex flex-1">
        {/* Menu lateral (desktop) */}
        <aside className="hidden w-56 shrink-0 border-r border-borda bg-fundo-1/50 lg:block">
          <nav aria-label="Principal" className="sticky top-14 p-2">
            {nomeSobrevivente && (
              <p className="mb-2 border-b border-borda px-3 pb-3 text-xs text-texto-suave">
                Sobrevivente
                <span className="block truncate text-sm text-texto">{nomeSobrevivente}</span>
              </p>
            )}
            <ul className="space-y-1">
              {ITENS_NAVEGACAO.map(({ href, rotulo, icone: Icone }) => (
                <li key={href}>
                  <Link
                    href={href}
                    aria-current={ativo(href) ? 'page' : undefined}
                    className={cn(
                      'relative flex min-h-[44px] items-center gap-3 border-l-2 px-3 text-sm transition-colors',
                      ativo(href)
                        ? 'border-acento-verde bg-acento-verde/10 text-texto'
                        : 'border-transparent text-texto-suave hover:bg-fundo-2 hover:text-texto',
                    )}
                  >
                    <Icone className="h-5 w-5" aria-hidden />
                    {rotulo}
                    <Bolinha ativa={indicadores[href]} />
                  </Link>
                </li>
              ))}
            </ul>
          </nav>
        </aside>

        <main id="conteudo" className="min-w-0 flex-1 px-4 py-6 pb-28 lg:px-8 lg:pb-8">
          {children}
        </main>

        {/* Painel direito (telas largas) */}
        <aside aria-label="Resumo" className="hidden w-72 shrink-0 space-y-4 border-l border-borda bg-fundo-1/50 p-4 xl:block">
          <Cartao titulo="Recursos" subtitulo={ab ? `No depósito · ${ab.nome}` : 'Escolha um abrigo'}>
            <ul className="space-y-2">
              {recursos.map(({ rotulo, icone: Icone, valor, baixo }) => (
                <li key={rotulo} className="flex items-center justify-between text-sm">
                  <span className="flex items-center gap-2 text-texto-suave">
                    <Icone className="h-4 w-4" aria-hidden />
                    {rotulo}
                  </span>
                  <span className={cn('font-mono', baixo && 'text-acento-vermelho')}>{valor}</span>
                </li>
              ))}
            </ul>
          </Cartao>
          <Cartao titulo="Alertas" indice={1}>
            {!ab ? (
              <EstadoVazio compacto texto="Sem abrigo ainda." detalhe="Escolha um na tela Abrigo." />
            ) : alertasAbrigo.length === 0 ? (
              <EstadoVazio compacto texto="Sem alertas no abrigo. Por enquanto." />
            ) : (
              <ul className="space-y-2">
                {alertasAbrigo.map(({ icone: Icone, texto, tom }) => (
                  <li key={texto}>
                    <Link href="/abrigo" className="flex items-start gap-2 text-sm hover:underline">
                      <Icone className={cn('mt-0.5 h-4 w-4 shrink-0', tom)} aria-hidden />
                      {texto}
                    </Link>
                  </li>
                ))}
              </ul>
            )}
          </Cartao>
        </aside>
      </div>

      {/* Navegação inferior (celular) */}
      <nav
        aria-label="Navegação principal móvel"
        className="fixed inset-x-0 bottom-0 z-30 border-t border-borda bg-fundo-1/95 pb-[env(safe-area-inset-bottom)] backdrop-blur lg:hidden"
      >
        <ul className="mx-auto grid max-w-xl grid-cols-6">
          {ITENS_MOBILE.map(({ href, rotulo, icone: Icone }) => (
            <li key={href}>
              <Link
                href={href}
                aria-current={ativo(href) ? 'page' : undefined}
                className={cn(
                  'relative flex min-h-[56px] flex-col items-center justify-center gap-0.5 text-[11px]',
                  ativo(href) ? 'text-acento-verde' : 'text-texto-suave',
                )}
              >
                <Icone className="h-5 w-5" aria-hidden />
                {rotulo}
                <Bolinha ativa={indicadores[href]} />
              </Link>
            </li>
          ))}
          <li>
            <button
              type="button"
              onClick={() => setMaisAberto(true)}
              aria-haspopup="dialog"
              className={cn(
                'flex min-h-[56px] w-full flex-col items-center justify-center gap-0.5 text-[11px]',
                maisAtivo ? 'text-acento-verde' : 'text-texto-suave',
              )}
            >
              <MoreHorizontal className="h-5 w-5" aria-hidden />
              Mais
            </button>
          </li>
        </ul>
      </nav>

      <Modal aberto={maisAberto} aoFechar={() => setMaisAberto(false)} titulo="Mais">
        {nomeSobrevivente && (
          <p className="mb-3 text-xs text-texto-suave">
            Sobrevivente: <span className="text-sm text-texto">{nomeSobrevivente}</span>
          </p>
        )}
        <ul className="grid grid-cols-2 gap-2">
          {ITENS_MAIS.map(({ href, rotulo, icone: Icone }) => (
            <li key={href}>
              <Link
                href={href}
                onClick={() => setMaisAberto(false)}
                className="flex min-h-[56px] items-center gap-3 rounded-md border border-borda px-3 text-sm hover:bg-fundo-2"
              >
                <Icone className="h-5 w-5 text-acento-verde" aria-hidden />
                {rotulo}
              </Link>
            </li>
          ))}
        </ul>
        <Botao
          variante="secundario"
          carregando={saindo}
          onClick={sair}
          icone={<LogOut className="h-4 w-4" aria-hidden />}
          className="mt-3 w-full"
        >
          Sair da conta
        </Botao>
      </Modal>
    </div>
  );
}
