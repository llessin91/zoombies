// tests/personagem.test.ts — criação, distribuição de pontos, moral e relógio do jogo
import { describe, expect, it } from 'vitest';
import { validarCriacao, validarDistribuicao, type Atributos } from '@/lib/game/atributos';
import { faixaMoral, modificadorMoral } from '@/lib/game/formulas';
import { relogioDoJogo } from '@/lib/game/tempo';
import { lerEstadoPersonagem } from '@/lib/game/personagem';

const LIMITES = { total: 12, minimo: 1, maximo: 3 };
const a = (f: number, ag: number, p: number, m: number, e: number, l: number): Atributos => ({
  forca: f, agilidade: ag, percepcao: p, medicina: m, engenharia: e, lideranca: l,
});

describe('criação do personagem', () => {
  it('aceita 12 pontos entre 1 e 3', () => {
    expect(validarCriacao(a(3, 2, 2, 2, 2, 1), LIMITES)).toBeNull();
  });
  it('recusa soma diferente de 12', () => {
    expect(validarCriacao(a(3, 3, 3, 3, 3, 3), LIMITES)).toMatch(/12/);
    expect(validarCriacao(a(1, 1, 1, 1, 1, 1), LIMITES)).toMatch(/12/);
  });
  it('recusa atributo fora de 1 a 3', () => {
    expect(validarCriacao(a(4, 2, 2, 2, 1, 1), LIMITES)).toMatch(/entre 1 e 3/);
    expect(validarCriacao(a(0, 3, 3, 3, 2, 1), LIMITES)).toMatch(/entre 1 e 3/);
  });
});

describe('distribuição de pontos', () => {
  const base = a(3, 2, 2, 2, 2, 1);
  it('aceita gastar pontos que tem', () => {
    expect(validarDistribuicao(base, a(2, 1, 0, 0, 0, 0), 3, 20)).toBeNull();
  });
  it('recusa gastar mais do que tem', () => {
    expect(validarDistribuicao(base, a(4, 0, 0, 0, 0, 0), 3, 20)).toMatch(/suficientes/);
  });
  it('recusa nada escolhido, valores negativos e passar do máximo', () => {
    expect(validarDistribuicao(base, a(0, 0, 0, 0, 0, 0), 3, 20)).toMatch(/pelo menos/);
    expect(validarDistribuicao(base, a(-1, 2, 0, 0, 0, 0), 3, 20)).toMatch(/inválidos/);
    expect(validarDistribuicao(a(19, 1, 1, 1, 1, 1), a(2, 0, 0, 0, 0, 0), 3, 20)).toMatch(/20/);
  });
});

describe('moral', () => {
  it('M = (moral − 50) / 10, de −5 a +5', () => {
    expect(modificadorMoral(70)).toBe(2);
    expect(modificadorMoral(50)).toBe(0);
    expect(modificadorMoral(100)).toBe(5);
    expect(modificadorMoral(0)).toBe(-5);
  });
  it('respeita os limites 0 e 100', () => {
    expect(modificadorMoral(150)).toBe(5);
    expect(modificadorMoral(-20)).toBe(-5);
  });
  it('descrição para o jogador nunca tem números', () => {
    for (const m of [0, 25, 50, 70, 95]) expect(faixaMoral(m).efeito).not.toMatch(/\d/);
  });
});

describe('relógio do jogo', () => {
  const T0 = Date.UTC(2026, 0, 1, 0, 0, 0);
  it('começa no Dia 1 na hora inicial', () => {
    expect(relogioDoJogo(T0, T0, 1, 8).texto).toBe('Dia 1 · 08:00');
  });
  it('1 hora real = 1 dia do jogo', () => {
    expect(relogioDoJogo(T0, T0 + 3_600_000, 1, 8).texto).toBe('Dia 2 · 08:00');
  });
  it('30 minutos reais = 12 horas do jogo', () => {
    expect(relogioDoJogo(T0, T0 + 1_800_000, 1, 8).texto).toBe('Dia 1 · 20:00');
  });
});

describe('estado vindo do banco', () => {
  it('null quando ainda não há personagem', () => {
    expect(lerEstadoPersonagem(null)).toBeNull();
  });
  it('estatísticas faltando viram zero', () => {
    const e = lerEstadoPersonagem({
      nome: 'Alice', nivel: 1, nivel_anunciado: 1, xp: 0, xp_proximo: 100, pontos_disponiveis: 0,
      atributos: { forca: 3, agilidade: 2, percepcao: 2, medicina: 2, engenharia: 2, lideranca: 1 },
      atributo_maximo: 20, moral: 70, stamina_atual: 20, stamina_maxima: 20,
      stamina_atualizada_em: '2026-01-01T00:00:00Z', segundos_por_ponto: 360, tutorial_etapa: 0,
      stats: {}, criado_em: '2026-01-01T00:00:00Z', dias_jogo_por_hora_real: 24, hora_inicial: 8,
      moral_divisor: 10, servidor_agora: '2026-01-01T00:00:00Z',
    });
    expect(e?.stats).toEqual({ missoes: 0, sucessos: 0, falhas: 0, sobreviventes_salvos: 0, zumbis_abatidos: 0 });
  });
});
