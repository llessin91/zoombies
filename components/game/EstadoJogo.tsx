'use client';

// src/components/game/EstadoJogo.tsx
// Guarda o estado do personagem no navegador para todas as telas do jogo.
// O servidor é a fonte da verdade: aqui só projetamos a stamina para a contagem regressiva
// (usando o relógio do SERVIDOR, não o do computador) e pedimos nova sincronização de tempos em tempos.

import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { pedirAcao } from '@/lib/api/cliente';
import type { EstadoPersonagem } from '@/lib/game/personagem';
import { segundosParaEncher, segundosParaProximoPonto, staminaRegenerada } from '@/lib/game/stamina';
import { ModalSubiuNivel } from './ModalSubiuNivel';

interface ContextoEstado {
  estado: EstadoPersonagem;
  /** Horário atual do servidor (ms), corrigindo a diferença do relógio do computador */
  agoraServidorMs: () => number;
  sincronizar: () => Promise<void>;
  aplicarEstado: (novo: EstadoPersonagem | null) => void;
}

const Contexto = createContext<ContextoEstado | null>(null);

const RESINCRONIZAR_MS = 120_000;

export function EstadoJogoProvider({ estadoInicial, children }: { estadoInicial: EstadoPersonagem; children: ReactNode }) {
  const [estado, setEstado] = useState(estadoInicial);
  // Diferença entre o relógio do servidor e o do computador
  const diferenca = useRef(Date.parse(estadoInicial.servidor_agora) - Date.now());
  const sincronizando = useRef(false);

  const aplicarEstado = useCallback((novo: EstadoPersonagem | null) => {
    if (!novo) return;
    diferenca.current = Date.parse(novo.servidor_agora) - Date.now();
    setEstado(novo);
  }, []);

  const sincronizar = useCallback(async () => {
    if (sincronizando.current) return;
    sincronizando.current = true;
    try {
      const r = await pedirAcao<{ estado: EstadoPersonagem | null }>('/api/personagem/estado');
      if (r.ok) aplicarEstado(r.dados.estado);
    } finally {
      sincronizando.current = false;
    }
  }, [aplicarEstado]);

  // Sincroniza ao voltar para a aba e a cada 2 minutos
  useEffect(() => {
    const aoVoltar = () => {
      if (document.visibilityState === 'visible') void sincronizar();
    };
    document.addEventListener('visibilitychange', aoVoltar);
    const id = window.setInterval(() => {
      if (document.visibilityState === 'visible') void sincronizar();
    }, RESINCRONIZAR_MS);
    return () => {
      document.removeEventListener('visibilitychange', aoVoltar);
      window.clearInterval(id);
    };
  }, [sincronizar]);

  const agoraServidorMs = useCallback(() => Date.now() + diferenca.current, []);

  const valor = useMemo(() => ({ estado, agoraServidorMs, sincronizar, aplicarEstado }), [estado, agoraServidorMs, sincronizar, aplicarEstado]);

  const subiuNivel = estado.nivel > estado.nivel_anunciado;

  async function fecharSubiuNivel() {
    // Some da tela na hora; o servidor registra que o jogador já viu
    setEstado((e) => ({ ...e, nivel_anunciado: e.nivel }));
    await pedirAcao('/api/personagem/nivel-visto');
  }

  return (
    <Contexto.Provider value={valor}>
      {children}
      <ModalSubiuNivel
        aberto={subiuNivel}
        nivel={estado.nivel}
        niveisGanhos={estado.nivel - estado.nivel_anunciado}
        pontosDisponiveis={estado.pontos_disponiveis}
        aoFechar={fecharSubiuNivel}
      />
    </Contexto.Provider>
  );
}

export function useEstadoJogo(): ContextoEstado {
  const c = useContext(Contexto);
  if (!c) throw new Error('useEstadoJogo precisa estar dentro de EstadoJogoProvider');
  return c;
}

/** Horário do servidor que avança a cada segundo (para contagens regressivas e relógio) */
export function useAgoraServidor(intervaloMs = 1000): number {
  const { agoraServidorMs, estado } = useEstadoJogo();
  // Começa no horário que veio do servidor: assim a página gerada no servidor e a do navegador batem
  const [agora, setAgora] = useState(() => Date.parse(estado.servidor_agora));
  useEffect(() => {
    setAgora(agoraServidorMs());
    const id = window.setInterval(() => setAgora(agoraServidorMs()), intervaloMs);
    return () => window.clearInterval(id);
  }, [agoraServidorMs, intervaloMs]);
  return agora;
}

/** Stamina projetada agora (só exibição) + quanto falta para o próximo ponto e para encher */
export function useStaminaProjetada() {
  const { estado } = useEstadoJogo();
  const agora = useAgoraServidor();
  const base = { atual: estado.stamina_atual, desdeMs: Date.parse(estado.stamina_atualizada_em) };
  const max = estado.stamina_maxima;
  const seg = estado.segundos_por_ponto;
  return {
    atual: staminaRegenerada(base, max, agora, seg).atual,
    maxima: max,
    proximoEm: segundosParaProximoPonto(base, max, agora, seg),
    encheEm: segundosParaEncher(base, max, agora, seg),
  };
}
