'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useState } from 'react';
import { Clock, Droplets, Fuel, HeartPulse, LogOut, MoreHorizontal, Plug, Star, Wheat, Zap } from 'lucide-react';
import { ITENS_MAIS, ITENS_MOBILE, ITENS_NAVEGACAO } from '@/lib/navegacao';
import { Barra } from '@/components/ui/Barra';
import { Botao } from '@/components/ui/Botao';
import { Cartao } from '@/components/ui/Cartao';
import { EstadoVazio } from '@/components/ui/Estados';
import { Modal } from '@/components/ui/Modal';
import { criarClienteNavegador } from '@/lib/supabase/client';
import { cn } from '@/lib/utils';

// Valores fixos só para visualizar o layout. A Fase 3 troca por dados reais.
const RESUMO_PROVISORIO = { nivel: 1, xp: 0, xpProximo: 100, stamina: 20, staminaMax: 20, moral: 70, relogio: 'Dia 1 · 08:00' };

// Bolinhas de notificação por rota (missão concluída, abrigo em alerta, etc.). Vazio até as fases certas.
const INDICADORES_PROVISORIOS: Record<string, boolean> = {};

const RECURSOS_PROVISORIOS = [
  { rotulo: 'Comida', icone: Wheat },
  { rotulo: 'Água', icone: Droplets },
  { rotulo: 'Combustível', icone: Fuel },
  { rotulo: 'Energia', icone: Plug },
];

function Bolinha({ ativa }: { ativa?: boolean }) {
  if (!ativa) return null;
  return <span aria-label="Novidade" className="absolute right-2 top-2 h-2.5 w-2.5 rounded-full bg-acento-vermelho ring-2 ring-fundo-1" />;
}

export function ShellJogo({ children, nomeSobrevivente }: { children: React.ReactNode; nomeSobrevivente?: string }) {
  const caminho = usePathname();
  const router = useRouter();
  const [saindo, setSaindo] = useState(false);
  const [maisAberto, setMaisAberto] = useState(false);
  const ativo = (href: string) => caminho === href || caminho.startsWith(`${href}/`);
  const r = RESUMO_PROVISORIO;
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
        <div className="flex h-14 items-center gap-3 px-4 lg:gap-6 lg:px-6">
          <Link href="/inicio" className="font-titulo text-xl tracking-[0.2em] text-acento-verde">
            ZOMBIES
          </Link>

          <div className="hidden items-center gap-2 md:flex">
            <Star className="h-4 w-4 text-acento-roxo" aria-hidden />
            <span className="text-sm">
              Nível <span className="font-mono">{r.nivel}</span>
            </span>
            <Barra valor={r.xp} max={r.xpProximo} tom="roxo" altura="sm" rotulo="Experiência" ocultarRotulo className="w-32" />
          </div>

          <div className="ml-auto flex items-center gap-4">
            <div className="flex items-center gap-2">
              <Zap className="h-4 w-4 text-acento-ambar" aria-hidden />
              <Barra valor={r.stamina} max={r.staminaMax} tom="ambar" altura="sm" brilho rotulo="Stamina" ocultarRotulo className="w-16 md:w-24" />
              <span className="font-mono text-xs">
                {r.stamina}/{r.staminaMax}
              </span>
            </div>
            <div className="flex items-center gap-2">
              <HeartPulse className="h-4 w-4 text-acento-vermelho" aria-hidden />
              <Barra valor={r.moral} max={100} tom="moral" altura="sm" rotulo="Moral" ocultarRotulo className="w-12 md:w-20" />
              <span className="font-mono text-xs">{r.moral}</span>
            </div>
            <div className="hidden items-center gap-1.5 text-sm text-texto-suave md:flex">
              <Clock className="h-4 w-4" aria-hidden />
              <span className="font-mono">{r.relogio}</span>
            </div>
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
                    <Bolinha ativa={INDICADORES_PROVISORIOS[href]} />
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
          <Cartao titulo="Recursos">
            <ul className="space-y-2">
              {RECURSOS_PROVISORIOS.map(({ rotulo, icone: Icone }) => (
                <li key={rotulo} className="flex items-center justify-between text-sm">
                  <span className="flex items-center gap-2 text-texto-suave">
                    <Icone className="h-4 w-4" aria-hidden />
                    {rotulo}
                  </span>
                  <span className="font-mono">—</span>
                </li>
              ))}
            </ul>
          </Cartao>
          <Cartao titulo="Alertas" indice={1}>
            <EstadoVazio compacto texto="Sem alertas no abrigo. Por enquanto." />
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
                <Bolinha ativa={INDICADORES_PROVISORIOS[href]} />
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
