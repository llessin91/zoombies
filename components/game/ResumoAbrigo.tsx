'use client';

// src/components/game/ResumoAbrigo.tsx
// Cartões do Início: resumo do abrigo e produção pronta (com "Coletar tudo").
// Os números vêm do estado do personagem, que o servidor monta depois do catch-up.

import { useState } from 'react';
import Link from 'next/link';
import { AlertTriangle, Droplets, Fuel, Hammer, PackageOpen, Wheat, Zap, ZapOff } from 'lucide-react';
import { Botao } from '@/components/ui/Botao';
import { EstadoVazio } from '@/components/ui/Estados';
import { useToast } from '@/components/ui/Toast';
import { pedirAcao } from '@/lib/api/cliente';
import type { EstadoAbrigo } from '@/lib/game/abrigo';
import { cn } from '@/lib/utils';
import { useEstadoJogo } from './EstadoJogo';

export function CartaoResumoAbrigo() {
  const { estado } = useEstadoJogo();
  const ab = estado.abrigo;
  if (!ab) {
    return (
      <div className="space-y-3">
        <EstadoVazio compacto texto="Você ainda não escolheu um abrigo." detalhe="Sem teto, sem depósito, sem produção." />
        <Link href="/abrigo" className="inline-flex text-sm text-acento-verde underline-offset-2 hover:underline">
          Escolher abrigo
        </Link>
      </div>
    );
  }
  const itens = [
    { icone: Wheat, rotulo: 'Comida', valor: ab.comida, ruim: ab.comida === 0 },
    { icone: Droplets, rotulo: 'Água', valor: ab.agua, ruim: ab.agua === 0 },
    { icone: Fuel, rotulo: 'Combustível', valor: ab.combustivel, ruim: false },
  ];
  return (
    <div className="space-y-3">
      <p className="font-medium">{ab.nome}</p>
      <ul className="grid grid-cols-3 gap-2 text-center">
        {itens.map(({ icone: Icone, rotulo, valor, ruim }) => (
          <li key={rotulo} className="rounded-md border border-borda px-2 py-2">
            <Icone className={cn('mx-auto h-4 w-4', ruim ? 'text-acento-vermelho' : 'text-texto-suave')} aria-hidden />
            <p className={cn('font-mono', ruim && 'text-acento-vermelho')}>{valor}</p>
            <p className="text-xs text-texto-suave">{rotulo}</p>
          </li>
        ))}
      </ul>
      <ul className="space-y-1 text-sm">
        <li className="flex items-center gap-2">
          {ab.tem_energia && !ab.energia_ok ? (
            <ZapOff className="h-4 w-4 text-acento-vermelho" aria-hidden />
          ) : (
            <Zap className="h-4 w-4 text-acento-ambar" aria-hidden />
          )}
          {!ab.tem_energia ? 'Sem gerador' : ab.energia_ok ? 'Energia ok' : 'Sem energia'}
        </li>
        {ab.construindo > 0 && (
          <li className="flex items-center gap-2">
            <Hammer className="h-4 w-4 text-acento-ambar" aria-hidden /> {ab.construindo} obra(s) em andamento
          </li>
        )}
        {ab.alertas > 0 && (
          <li className="flex items-center gap-2 text-acento-vermelho">
            <AlertTriangle className="h-4 w-4" aria-hidden /> Tem instalação precisando de atenção
          </li>
        )}
      </ul>
      <Link href="/abrigo" className="inline-flex text-sm text-acento-verde underline-offset-2 hover:underline">
        Ir ao abrigo
      </Link>
    </div>
  );
}

export function CartaoProducaoPronta() {
  const { estado, sincronizar } = useEstadoJogo();
  const toast = useToast();
  const [enviando, setEnviando] = useState(false);
  const ab = estado.abrigo;
  if (!ab) return <EstadoVazio compacto texto="Nada para coletar." detalhe="Sem abrigo, sem produção." />;
  if (ab.producao_pronta === 0) return <EstadoVazio compacto texto="Nada para coletar." detalhe="Hortas, captação de água e afins enchem com o tempo." />;

  async function coletar() {
    setEnviando(true);
    const r = await pedirAcao<{ estado: EstadoAbrigo }>('/api/abrigo/coletar', {});
    setEnviando(false);
    if (!r.ok) {
      toast.erro('Não deu certo', r.erro);
      return;
    }
    const n = r.dados.estado.tem_abrigo ? (r.dados.estado.coletado ?? 0) : 0;
    toast.sucesso(`Coletou ${n} item(ns)`, 'Foi tudo para o depósito.');
    void sincronizar();
  }

  return (
    <div className="flex items-center justify-between gap-3">
      <p className="flex items-center gap-2 text-sm">
        <PackageOpen className="h-5 w-5 text-acento-verde" aria-hidden />
        {ab.producao_pronta} instalação(ões) com produção pronta.
      </p>
      <Botao carregando={enviando} onClick={coletar}>
        Coletar tudo
      </Botao>
    </div>
  );
}
