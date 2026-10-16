// src/lib/game/progressao.ts
// Curva de XP, pontos por nível e aplicação de XP.
// Espelha as funções SQL xp_para_subir, pontos_ao_alcancar e conceder_xp (migration 0006).
// Quem decide de verdade é o banco; aqui servem para testes e para a tela explicar números.

import { CONFIG_PADRAO, type ConfigJogo } from './config';

/** XP necessário para ir do nível `nivel` para o próximo */
export function xpParaSubir(nivel: number, cfg: ConfigJogo = CONFIG_PADRAO): number {
  if (!Number.isInteger(nivel) || nivel < 1) throw new Error('Nível inválido.');
  const lista = cfg.xp.paraSubirAteNivel10;
  if (nivel <= lista.length) return lista[nivel - 1];
  // Depois da tabela: +incremento por nível (10→11 = 1350 + 350 = 1700)
  return lista[lista.length - 1] + (nivel - lista.length) * cfg.xp.incrementoAposNivel10;
}

/** Pontos de atributo ganhos ao ALCANÇAR o nível `nivel` */
export function pontosAoAlcancar(nivel: number, cfg: ConfigJogo = CONFIG_PADRAO): number {
  return nivel <= cfg.xp.ultimoNivelComMaisPontos ? cfg.xp.pontosAteLimite : cfg.xp.pontosDepoisLimite;
}

export interface Progresso {
  nivel: number;
  /** XP dentro do nível atual */
  xp: number;
  pontosDisponiveis: number;
}

export interface ResultadoXp extends Progresso {
  xpGanho: number;
  niveisGanhos: number;
  pontosGanhos: number;
}

/** Aplica XP (com o multiplicador) e sobe quantos níveis couberem, mantendo a sobra */
export function aplicarXp(atual: Progresso, xpBase: number, multiplicador = 1, cfg: ConfigJogo = CONFIG_PADRAO): ResultadoXp {
  if (xpBase < 0) throw new Error('XP inválido.');
  const xpGanho = Math.floor(xpBase * multiplicador);
  let xp = atual.xp + xpGanho;
  let nivel = atual.nivel;
  let niveisGanhos = 0;
  let pontosGanhos = 0;

  while (xp >= xpParaSubir(nivel, cfg)) {
    xp -= xpParaSubir(nivel, cfg);
    nivel += 1;
    niveisGanhos += 1;
    pontosGanhos += pontosAoAlcancar(nivel, cfg);
  }

  return { nivel, xp, pontosDisponiveis: atual.pontosDisponiveis + pontosGanhos, xpGanho, niveisGanhos, pontosGanhos };
}

/** XP total acumulado desde o nível 1 (útil para estatísticas) */
export function xpTotal(nivel: number, xpNoNivel: number, cfg: ConfigJogo = CONFIG_PADRAO): number {
  let total = xpNoNivel;
  for (let n = 1; n < nivel; n++) total += xpParaSubir(n, cfg);
  return total;
}
