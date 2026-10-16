// tests/stamina.test.ts — regeneração de stamina por tempo e teto máximo
import { describe, expect, it } from 'vitest';
import { formatarDuracao, segundosParaEncher, segundosParaProximoPonto, staminaMaxima, staminaRegenerada } from '@/lib/game/stamina';

const SEG = 6 * 60; // 6 minutos por ponto (padrão)
const MIN = 60_000;
const T0 = Date.UTC(2026, 0, 1, 12, 0, 0);

describe('regeneração de stamina', () => {
  it('não recupera nada antes de completar 6 minutos', () => {
    const r = staminaRegenerada({ atual: 5, desdeMs: T0 }, 20, T0 + 5 * MIN + 59_000, SEG);
    expect(r).toEqual({ atual: 5, desdeMs: T0 });
  });

  it('recupera 1 ponto a cada 6 minutos (10 por hora)', () => {
    expect(staminaRegenerada({ atual: 5, desdeMs: T0 }, 20, T0 + 6 * MIN, SEG).atual).toBe(6);
    expect(staminaRegenerada({ atual: 5, desdeMs: T0 }, 20, T0 + 60 * MIN, SEG).atual).toBe(15);
  });

  it('guarda a sobra de tempo para o próximo ponto', () => {
    // 33 minutos = 5 pontos + 3 minutos guardados
    const r = staminaRegenerada({ atual: 5, desdeMs: T0 }, 20, T0 + 33 * MIN, SEG);
    expect(r.atual).toBe(10);
    expect(r.desdeMs).toBe(T0 + 30 * MIN);
  });

  it('nunca passa do máximo, mesmo depois de muito tempo', () => {
    const r = staminaRegenerada({ atual: 0, desdeMs: T0 }, 20, T0 + 48 * 60 * MIN, SEG);
    expect(r.atual).toBe(20);
  });

  it('cheia: o relógio recomeça agora', () => {
    const agora = T0 + 99 * MIN;
    expect(staminaRegenerada({ atual: 20, desdeMs: T0 }, 20, agora, SEG)).toEqual({ atual: 20, desdeMs: agora });
  });

  it('ignora horário "no futuro" (relógio errado não dá stamina grátis)', () => {
    expect(staminaRegenerada({ atual: 5, desdeMs: T0 + 60 * MIN }, 20, T0, SEG).atual).toBe(5);
  });

  it('aplicar duas vezes seguidas dá o mesmo resultado (sem duplicar pontos)', () => {
    const a = staminaRegenerada({ atual: 3, desdeMs: T0 }, 20, T0 + 20 * MIN, SEG);
    const b = staminaRegenerada(a, 20, T0 + 20 * MIN, SEG);
    expect(b).toEqual(a);
  });
});

describe('máximo com bônus', () => {
  it('apartamento barricado: +10% (20 → 22)', () => {
    expect(staminaMaxima(20, 10)).toBe(22);
  });
  it('sem bônus continua 20; arredonda para baixo', () => {
    expect(staminaMaxima(20)).toBe(20);
    expect(staminaMaxima(21, 10)).toBe(23);
  });
});

describe('contagem regressiva', () => {
  it('mostra quanto falta para o próximo ponto', () => {
    expect(segundosParaProximoPonto({ atual: 5, desdeMs: T0 }, 20, T0 + 2 * MIN, SEG)).toBe(4 * 60);
  });
  it('null quando cheia', () => {
    expect(segundosParaProximoPonto({ atual: 20, desdeMs: T0 }, 20, T0, SEG)).toBeNull();
    expect(segundosParaEncher({ atual: 20, desdeMs: T0 }, 20, T0, SEG)).toBeNull();
  });
  it('tempo para encher', () => {
    // faltam 2 pontos: 6 min + 6 min
    expect(segundosParaEncher({ atual: 18, desdeMs: T0 }, 20, T0, SEG)).toBe(12 * 60);
  });
  it('formata durações', () => {
    expect(formatarDuracao(245)).toBe('4:05');
    expect(formatarDuracao(3720)).toBe('1h 02min');
  });
});
