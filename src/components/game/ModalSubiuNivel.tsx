'use client';

// src/components/game/ModalSubiuNivel.tsx
// Comemoração de subida de nível: brilho e explosão de partículas leves (só transform/opacity).
// Som: desligado por padrão; a opção de ligar chega em Ajustes (Fase 13).

import Link from 'next/link';
import { motion, useReducedMotion } from 'framer-motion';
import { Star } from 'lucide-react';
import { Modal } from '@/components/ui/Modal';
import { Botao } from '@/components/ui/Botao';

const PARTICULAS = 28;
const CORES = ['bg-acento-roxo', 'bg-acento-ambar', 'bg-acento-verde'];

interface Props {
  aberto: boolean;
  nivel: number;
  niveisGanhos: number;
  pontosDisponiveis: number;
  aoFechar: () => void;
}

export function ModalSubiuNivel({ aberto, nivel, niveisGanhos, pontosDisponiveis, aoFechar }: Props) {
  const reduzir = useReducedMotion();

  return (
    <Modal aberto={aberto} aoFechar={aoFechar} titulo="Subiu de nível!">
      <div className="relative flex flex-col items-center gap-4 py-4 text-center">
        {/* Explosão de partículas */}
        {!reduzir && (
          <div aria-hidden className="pointer-events-none absolute left-1/2 top-16 h-0 w-0">
            {Array.from({ length: PARTICULAS }, (_, i) => {
              const angulo = (i / PARTICULAS) * Math.PI * 2;
              const distancia = 70 + (i % 4) * 22;
              return (
                <motion.span
                  key={i}
                  className={`absolute h-2 w-2 rounded-full ${CORES[i % CORES.length]}`}
                  initial={{ x: 0, y: 0, opacity: 1, scale: 1 }}
                  animate={{ x: Math.cos(angulo) * distancia, y: Math.sin(angulo) * distancia, opacity: 0, scale: 0.3 }}
                  transition={{ duration: 1.1, ease: 'easeOut', delay: 0.1 + (i % 3) * 0.05 }}
                />
              );
            })}
          </div>
        )}

        {/* Selo com brilho */}
        <motion.div
          className="relative flex h-28 w-28 items-center justify-center rounded-full border-2 border-acento-roxo bg-acento-roxo/15"
          initial={reduzir ? false : { scale: 0.4, rotate: -20 }}
          animate={{ scale: 1, rotate: 0 }}
          transition={{ type: 'spring', stiffness: 220, damping: 12 }}
          style={{ boxShadow: '0 0 40px rgb(var(--acento-roxo) / 0.55)' }}
        >
          <Star className="absolute h-24 w-24 text-acento-roxo/25" aria-hidden />
          <span className="relative font-titulo text-5xl">{nivel}</span>
        </motion.div>

        <div className="space-y-1">
          <p className="text-lg">
            Nível <span className="font-mono">{nivel}</span>
            {niveisGanhos > 1 && <span className="text-texto-suave"> (+{niveisGanhos} níveis)</span>}
          </p>
          <p className="text-sm text-texto-suave">Mais forte, mais esperto, igualmente cansado.</p>
        </div>

        {pontosDisponiveis > 0 && (
          <p className="rounded-md border border-acento-ambar/50 bg-acento-ambar/10 px-3 py-2 text-sm">
            Você tem <span className="font-mono font-semibold">{pontosDisponiveis}</span> ponto(s) de atributo para distribuir.
          </p>
        )}

        <div className="flex w-full flex-col gap-2 sm:flex-row">
          {pontosDisponiveis > 0 && (
            <Link
              href="/personagem"
              onClick={aoFechar}
              className="inline-flex min-h-[44px] flex-1 items-center justify-center rounded-md border border-acento-verde bg-acento-verde/20 px-4 text-sm font-medium hover:bg-acento-verde/30 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde"
            >
              Distribuir pontos
            </Link>
          )}
          <Botao variante="secundario" onClick={aoFechar} className="flex-1">
            {pontosDisponiveis > 0 ? 'Depois' : 'Continuar'}
          </Botao>
        </div>
      </div>
    </Modal>
  );
}
