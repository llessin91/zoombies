// tests/missoes.test.ts — fórmula de sucesso, faixas, desbloqueio, cooldown de local e carga
import { describe, expect, it } from 'vitest';
import type { Atributos } from '@/lib/game/atributos';
import { montarConfig } from '@/lib/game/config';
import {
  capacidadeCarga,
  chanceSucesso,
  cooldownMsReais,
  diasDoJogoRestantes,
  faixaChance,
  habilidadePonderada,
  motivoRegiaoBloqueada,
} from '@/lib/game/missoes';

const attr = (f: number, ag: number, p: number, m: number, e: number, l: number): Atributos => ({
  forca: f, agilidade: ag, percepcao: p, medicina: m, engenharia: e, lideranca: l,
});

describe('habilidade ponderada (H)', () => {
  it('exemplo do prompt: Percepção 50%, Agilidade 25%, Força 15%, Medicina 10%', () => {
    const h = habilidadePonderada(attr(4, 4, 8, 2, 1, 1), { percepcao: 50, agilidade: 25, forca: 15, medicina: 10 });
    expect(h).toBeCloseTo(4 + 1 + 0.6 + 0.2);
  });
  it('atributo sem peso não conta', () => {
    expect(habilidadePonderada(attr(20, 1, 1, 1, 1, 1), { percepcao: 100 })).toBe(1);
  });
});

describe('fórmula de sucesso (P)', () => {
  it('H igual a D e moral 50 dá exatamente 50', () => {
    expect(chanceSucesso(3, 'facil', 50)).toBe(50);
  });
  it('cada ponto de diferença entre H e D vale 5', () => {
    expect(chanceSucesso(5, 'facil', 50)).toBe(60);
    expect(chanceSucesso(4, 'media', 50)).toBe(40);
  });
  it('nunca passa de 95 (ninguém é invencível)', () => {
    expect(chanceSucesso(20, 'facil', 100, { b: 30, e: 20 })).toBe(95);
  });
  it('nunca fica abaixo de 5', () => {
    expect(chanceSucesso(1, 'lendaria', 0, { i: 50 })).toBe(5);
  });
  it('B soma, I subtrai, E soma ou subtrai', () => {
    expect(chanceSucesso(3, 'facil', 50, { b: 10 })).toBe(60);
    expect(chanceSucesso(3, 'facil', 50, { i: 10 })).toBe(40);
    expect(chanceSucesso(3, 'facil', 50, { e: -7 })).toBe(43);
  });
  it('moral: (moral − 50) / 10', () => {
    expect(chanceSucesso(3, 'facil', 70)).toBe(52);
    expect(chanceSucesso(3, 'facil', 0)).toBe(45);
    expect(chanceSucesso(3, 'facil', 100)).toBe(55);
  });
  it('usa os números do game_config', () => {
    const cfg = montarConfig([{ chave: 'missao.formula', valor: { base: 40, peso_diferenca: 10, minimo: 1, maximo: 99 } }]);
    expect(chanceSucesso(4, 'facil', 50, {}, cfg)).toBe(50);
  });
});

describe('faixa qualitativa', () => {
  it('converte a chance em faixa (padrões 70 / 45 / 25)', () => {
    expect(faixaChance(95)).toBe('segura');
    expect(faixaChance(70)).toBe('segura');
    expect(faixaChance(69.9)).toBe('equilibrada');
    expect(faixaChance(45)).toBe('equilibrada');
    expect(faixaChance(30)).toBe('arriscada');
    expect(faixaChance(5)).toBe('muito_arriscada');
  });
});

describe('desbloqueio de regiões', () => {
  const industrial = { nivelMinimo: 8, itemAcesso: { slug: 'credencial_industrial', nome: 'Credencial industrial' } };
  it('Periferia liberada no nível 1', () => {
    expect(motivoRegiaoBloqueada({ nivelMinimo: 1 }, 1, new Set())).toBeNull();
  });
  it('Centro pede nível 4', () => {
    expect(motivoRegiaoBloqueada({ nivelMinimo: 4 }, 3, new Set())).toBe('Requer nível 4');
    expect(motivoRegiaoBloqueada({ nivelMinimo: 4 }, 4, new Set())).toBeNull();
  });
  it('Industrial pede nível E item; mostra o que falta', () => {
    expect(motivoRegiaoBloqueada(industrial, 5, new Set())).toBe('Requer nível 8 e Credencial industrial');
    expect(motivoRegiaoBloqueada(industrial, 9, new Set())).toBe('Requer Credencial industrial');
    expect(motivoRegiaoBloqueada(industrial, 7, new Set(['credencial_industrial']))).toBe('Requer nível 8');
    expect(motivoRegiaoBloqueada(industrial, 8, new Set(['credencial_industrial']))).toBeNull();
  });
});

describe('cooldown de local', () => {
  it('fácil: 3 dias do jogo = 3 horas reais (1 dia por hora)', () => {
    expect(cooldownMsReais('facil')).toBe(3 * 3_600_000);
    expect(cooldownMsReais('lendaria')).toBe(12 * 3_600_000);
  });
  it('local com cooldown próprio ignora a dificuldade', () => {
    expect(cooldownMsReais('facil', undefined, 1)).toBe(3_600_000);
  });
  it('acompanha a velocidade do relógio do jogo', () => {
    const cfg = montarConfig([{ chave: 'tempo.dias_jogo_por_hora_real', valor: 2 }]);
    expect(cooldownMsReais('facil', cfg)).toBe(1.5 * 3_600_000);
  });
  it('dias restantes arredondam para cima e nunca ficam negativos', () => {
    const agora = 1_000_000;
    expect(diasDoJogoRestantes(agora + 2.1 * 3_600_000, agora)).toBe(3);
    expect(diasDoJogoRestantes(agora - 10, agora)).toBe(0);
  });
});

describe('capacidade de carga', () => {
  it('base 10 + Força × 2', () => {
    expect(capacidadeCarga(1)).toBe(12);
    expect(capacidadeCarga(7)).toBe(24);
  });
});
