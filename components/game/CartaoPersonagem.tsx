'use client';

// src/components/game/CartaoPersonagem.tsx
// Resumo do personagem para a tela Início: nome, nível, XP, stamina com contagem e moral.

import Link from 'next/link';
import { HeartPulse, User } from 'lucide-react';
import { Barra } from '@/components/ui/Barra';
import { Cartao } from '@/components/ui/Cartao';
import { Selo } from '@/components/ui/Selo';
import { faixaMoral } from '@/lib/game/formulas';
import { BarraStamina } from './BarraStamina';
import { useEstadoJogo } from './EstadoJogo';

export function CartaoPersonagem() {
  const { estado } = useEstadoJogo();
  const moral = faixaMoral(estado.moral);

  return (
    <Cartao
      titulo={estado.nome}
      subtitulo={`Nível ${estado.nivel}`}
      icone={<User className="h-6 w-6 text-acento-verde" aria-hidden />}
      acao={
        estado.pontos_disponiveis > 0 ? (
          <Link href="/personagem" className="rounded focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde">
            <Selo tom="ambar">{estado.pontos_disponiveis} ponto(s) para distribuir</Selo>
          </Link>
        ) : undefined
      }
      variante="destaque"
    >
      <div className="space-y-4">
        <div>
          <Barra valor={estado.xp} max={estado.xp_proximo} tom="roxo" rotulo="Experiência" mostrarValor />
        </div>
        <BarraStamina />
        <div className="space-y-1.5">
          <div className="flex items-center justify-between text-sm">
            <span className="flex items-center gap-2">
              <HeartPulse className="h-4 w-4 text-acento-vermelho" aria-hidden />
              Moral
            </span>
            <span className="font-mono">{estado.moral}</span>
          </div>
          <Barra valor={estado.moral} max={100} tom="moral" rotulo="Moral" ocultarRotulo />
          <p className="text-xs text-texto-suave">{moral.rotulo}</p>
        </div>
        <Link href="/personagem" className="inline-block text-sm text-acento-verde hover:underline">
          Ver personagem
        </Link>
      </div>
    </Cartao>
  );
}
