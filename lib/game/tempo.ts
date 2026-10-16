// src/lib/game/tempo.ts
// Relógio do jogo. O tempo do jogo corre mais rápido que o real (padrão: 1 hora real = 1 dia do jogo).
// Cada sobrevivente conta os próprios dias a partir da criação do personagem (Dia 1, hora inicial).

export interface RelogioJogo {
  dia: number;
  hora: number;
  minuto: number;
  texto: string;
}

const MS_POR_HORA = 3_600_000;

/** Dias do jogo que passam em `ms` milissegundos reais */
export function diasDoJogo(ms: number, diasPorHoraReal: number): number {
  return (Math.max(0, ms) / MS_POR_HORA) * diasPorHoraReal;
}

/** Converte dias do jogo em milissegundos reais */
export function msReaisDeDiasDoJogo(dias: number, diasPorHoraReal: number): number {
  return (dias / diasPorHoraReal) * MS_POR_HORA;
}

export function relogioDoJogo(inicioMs: number, agoraMs: number, diasPorHoraReal: number, horaInicial: number): RelogioJogo {
  // Total de horas do jogo desde o início, já somando a hora em que o Dia 1 começa
  const horasJogo = diasDoJogo(agoraMs - inicioMs, diasPorHoraReal) * 24 + horaInicial;
  const dia = Math.floor(horasJogo / 24) + 1;
  const horaDecimal = horasJogo % 24;
  const hora = Math.floor(horaDecimal);
  const minuto = Math.floor((horaDecimal - hora) * 60);
  return { dia, hora, minuto, texto: `Dia ${dia} · ${String(hora).padStart(2, '0')}:${String(minuto).padStart(2, '0')}` };
}
