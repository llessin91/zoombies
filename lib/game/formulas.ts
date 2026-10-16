// src/lib/game/formulas.ts
// Fórmulas de jogo. Nesta fase: o modificador de moral (M).
// A fórmula completa de sucesso da missão entra na Fase 5.

/** M = (moral − 50) / divisor, em pontos percentuais (padrão: de −5 a +5) */
export function modificadorMoral(moral: number, divisor = 10): number {
  const m = Math.min(100, Math.max(0, moral));
  return (m - 50) / divisor;
}

export type FaixaMoral = 'alta' | 'boa' | 'neutra' | 'baixa' | 'critica';

/** Descrição SEM números para o jogador (o jogo nunca mostra cálculos) */
export function faixaMoral(moral: number): { faixa: FaixaMoral; rotulo: string; efeito: string } {
  if (moral >= 80) return { faixa: 'alta', rotulo: 'Alta', efeito: 'Ajuda nas missões. Confiança demais também mata, mas hoje não.' };
  if (moral >= 60) return { faixa: 'boa', rotulo: 'Boa', efeito: 'Ajuda um pouco nas missões.' };
  if (moral >= 40) return { faixa: 'neutra', rotulo: 'Estável', efeito: 'Não ajuda nem atrapalha.' };
  if (moral >= 20) return { faixa: 'baixa', rotulo: 'Baixa', efeito: 'Atrapalha um pouco nas missões.' };
  return { faixa: 'critica', rotulo: 'Crítica', efeito: 'Atrapalha nas missões. Coma algo, descanse, não olhe pela janela.' };
}
