// src/lib/game/missoes.ts
// Regras de missões em TypeScript. Espelham as funções SQL da migration 0007
// (chance_missao, faixa_chance, motivo_regiao_bloqueada, aplicar_cooldown_local, capacidade_carga).
// Quem decide de verdade é o banco; aqui ficam os testes e textos da tela.

import type { Atributos } from './atributos';
import { CONFIG_PADRAO, type ConfigJogo, type Dificuldade } from './config';

export type Categoria = 'exploracao' | 'coleta_materiais' | 'coleta_combustivel' | 'resgate' | 'combate' | 'chefe';
export type FaixaChance = 'segura' | 'equilibrada' | 'arriscada' | 'muito_arriscada';
export type EstadoMissao = 'disponivel' | 'bloqueada' | 'esgotada';

export const CATEGORIAS: { valor: Categoria; rotulo: string }[] = [
  { valor: 'exploracao', rotulo: 'Exploração' },
  { valor: 'coleta_materiais', rotulo: 'Coleta de materiais' },
  { valor: 'coleta_combustivel', rotulo: 'Coleta de combustível' },
  { valor: 'resgate', rotulo: 'Resgate' },
  { valor: 'combate', rotulo: 'Combate' },
  { valor: 'chefe', rotulo: 'Chefe' },
];

export const DIFICULDADES: { valor: Dificuldade; rotulo: string }[] = [
  { valor: 'facil', rotulo: 'Fácil' },
  { valor: 'media', rotulo: 'Média' },
  { valor: 'dificil', rotulo: 'Difícil' },
  { valor: 'lendaria', rotulo: 'Lendária' },
];

export const FAIXAS: Record<FaixaChance, { rotulo: string; dica: string }> = {
  segura: { rotulo: 'Segura', dica: 'Boas chances. Ainda é o fim do mundo, então nada de relaxar.' },
  equilibrada: { rotulo: 'Equilibrada', dica: 'Pode dar certo, pode dar errado. Como tudo agora.' },
  arriscada: { rotulo: 'Arriscada', dica: 'As chances não estão do seu lado. Uma boa arma ajudaria.' },
  muito_arriscada: { rotulo: 'Muito arriscada', dica: 'Você provavelmente não está pronto. Os zumbis estão.' },
};

/** H: habilidade ponderada = soma(atributo × peso%) */
export function habilidadePonderada(atributos: Atributos, pesos: Partial<Record<keyof Atributos, number>>): number {
  let h = 0;
  for (const [k, peso] of Object.entries(pesos)) {
    h += (atributos[k as keyof Atributos] ?? 0) * ((peso ?? 0) / 100);
  }
  return h;
}

export interface Modificadores {
  /** B: bônus de armas, consumíveis, instalações */
  b?: number;
  /** I: penalidades (ferimentos, doença, carga excessiva, fome) */
  i?: number;
  /** E: efeito das escolhas em eventos */
  e?: number;
}

/** P = min(95, max(5, 50 + (H − D) × 5 + B + M − I + E)) */
export function chanceSucesso(
  h: number,
  dificuldade: Dificuldade,
  moral: number,
  mods: Modificadores = {},
  cfg: ConfigJogo = CONFIG_PADRAO,
): number {
  const f = cfg.missao.formula;
  const d = cfg.missao.dificuldadeNumerica[dificuldade];
  const m = (Math.min(100, Math.max(0, moral)) - 50) / cfg.moral.divisorModificador;
  const p = f.base + (h - d) * f.pesoDiferenca + (mods.b ?? 0) + m - (mods.i ?? 0) + (mods.e ?? 0);
  return Math.min(f.maximo, Math.max(f.minimo, p));
}

/** Converte a chance em faixa qualitativa. É só isto que o jogador vê. */
export function faixaChance(p: number, cfg: ConfigJogo = CONFIG_PADRAO): FaixaChance {
  const f = cfg.missao.faixas;
  if (p >= f.segura) return 'segura';
  if (p >= f.equilibrada) return 'equilibrada';
  if (p >= f.arriscada) return 'arriscada';
  return 'muito_arriscada';
}

export interface RegiaoRequisito {
  nivelMinimo: number;
  itemAcesso?: { slug: string; nome: string } | null;
}

/** Motivo do bloqueio da região, ou null se está liberada */
export function motivoRegiaoBloqueada(r: RegiaoRequisito, nivel: number, itensDoJogador: Set<string>): string | null {
  const partes: string[] = [];
  if (nivel < r.nivelMinimo) partes.push(`nível ${r.nivelMinimo}`);
  if (r.itemAcesso && !itensDoJogador.has(r.itemAcesso.slug)) partes.push(r.itemAcesso.nome);
  return partes.length ? `Requer ${partes.join(' e ')}` : null;
}

/** Quanto tempo REAL um local fica esgotado (cooldown em dias do jogo) */
export function cooldownMsReais(dificuldade: Dificuldade, cfg: ConfigJogo = CONFIG_PADRAO, diasDoLocal?: number | null): number {
  const dias = diasDoLocal ?? cfg.missao.cooldownLocalDias[dificuldade];
  return (dias / cfg.tempo.diasJogoPorHoraReal) * 3_600_000;
}

/** Dias do jogo que faltam (arredonda para cima) */
export function diasDoJogoRestantes(disponivelEmMs: number, agoraMs: number, cfg: ConfigJogo = CONFIG_PADRAO): number {
  const ms = Math.max(0, disponivelEmMs - agoraMs);
  return Math.ceil((ms / 3_600_000) * cfg.tempo.diasJogoPorHoraReal);
}

/** Capacidade de carga em expedição = base + Força × por ponto */
export function capacidadeCarga(forca: number, cfg: ConfigJogo = CONFIG_PADRAO): number {
  return cfg.carga.base + forca * cfg.carga.porPontoForca;
}

/** "30 s", "1 min 30 s" */
export function formatarSegundos(seg: number): string {
  if (seg < 60) return `${seg} s`;
  const m = Math.floor(seg / 60);
  const s = seg % 60;
  return s ? `${m} min ${s} s` : `${m} min`;
}
