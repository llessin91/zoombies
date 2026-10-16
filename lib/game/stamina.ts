// src/lib/game/stamina.ts
// Regeneração de stamina por horário ("catch-up"), sem timer no navegador.
// Espelha a função SQL stamina_regenerada (migration 0006).
// No navegador, isto só PROJETA o valor para a contagem regressiva; o banco é quem grava.

/** Máximo de stamina com bônus percentual (ex.: abrigo +10%) */
export function staminaMaxima(base: number, bonusPct = 0): number {
  return Math.floor((base * (100 + bonusPct)) / 100);
}

export interface EstadoStamina {
  atual: number;
  /** Horário (ms) a partir do qual conta o próximo ponto */
  desdeMs: number;
}

/** Quantos pontos voltaram entre `desdeMs` e `agoraMs`. Guarda a sobra de tempo. */
export function staminaRegenerada(
  estado: EstadoStamina,
  maxima: number,
  agoraMs: number,
  segundosPorPonto: number,
): EstadoStamina {
  if (estado.atual >= maxima) return { atual: estado.atual, desdeMs: agoraMs };

  const msPorPonto = segundosPorPonto * 1000;
  const decorrido = Math.max(0, agoraMs - estado.desdeMs);
  const pontos = Math.floor(decorrido / msPorPonto);
  const novo = Math.min(maxima, estado.atual + pontos);

  if (novo >= maxima) return { atual: novo, desdeMs: agoraMs };
  return { atual: novo, desdeMs: estado.desdeMs + pontos * msPorPonto };
}

/** Segundos até o próximo ponto (null se já está cheia) */
export function segundosParaProximoPonto(
  estado: EstadoStamina,
  maxima: number,
  agoraMs: number,
  segundosPorPonto: number,
): number | null {
  const r = staminaRegenerada(estado, maxima, agoraMs, segundosPorPonto);
  if (r.atual >= maxima) return null;
  const restante = segundosPorPonto * 1000 - (agoraMs - r.desdeMs);
  return Math.max(0, Math.ceil(restante / 1000));
}

/** Segundos até encher (null se já está cheia) */
export function segundosParaEncher(estado: EstadoStamina, maxima: number, agoraMs: number, segundosPorPonto: number): number | null {
  const proximo = segundosParaProximoPonto(estado, maxima, agoraMs, segundosPorPonto);
  if (proximo === null) return null;
  const r = staminaRegenerada(estado, maxima, agoraMs, segundosPorPonto);
  return proximo + (maxima - r.atual - 1) * segundosPorPonto;
}

/** "4:05" ou "1h 02min" */
export function formatarDuracao(segundos: number): string {
  const s = Math.max(0, Math.round(segundos));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const seg = s % 60;
  if (h > 0) return `${h}h ${String(m).padStart(2, '0')}min`;
  return `${m}:${String(seg).padStart(2, '0')}`;
}
