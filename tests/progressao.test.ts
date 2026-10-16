// tests/progressao.test.ts — curva de XP e pontos por nível
import { describe, expect, it } from 'vitest';
import { CONFIG_PADRAO, montarConfig } from '@/lib/game/config';
import { aplicarXp, pontosAoAlcancar, xpParaSubir, xpTotal } from '@/lib/game/progressao';

describe('curva de XP', () => {
  it('segue a tabela do prompt até o nível 10', () => {
    const esperado = [100, 150, 220, 320, 450, 600, 800, 1050, 1350];
    esperado.forEach((xp, i) => expect(xpParaSubir(i + 1)).toBe(xp));
  });

  it('do 10 em diante soma 350 por nível', () => {
    expect(xpParaSubir(10)).toBe(1700);
    expect(xpParaSubir(11)).toBe(2050);
    expect(xpParaSubir(12)).toBe(2400);
    expect(xpParaSubir(20)).toBe(1350 + 11 * 350);
  });

  it('recusa nível inválido', () => {
    expect(() => xpParaSubir(0)).toThrow();
    expect(() => xpParaSubir(1.5)).toThrow();
  });
});

describe('pontos por nível', () => {
  it('dá 3 pontos ao chegar nos níveis 2 a 10', () => {
    for (let n = 2; n <= 10; n++) expect(pontosAoAlcancar(n)).toBe(3);
  });

  it('muda para 2 pontos a partir do nível 11', () => {
    expect(pontosAoAlcancar(10)).toBe(3);
    expect(pontosAoAlcancar(11)).toBe(2);
    expect(pontosAoAlcancar(30)).toBe(2);
  });
});

describe('aplicar XP', () => {
  const inicio = { nivel: 1, xp: 0, pontosDisponiveis: 0 };

  it('não sobe de nível antes da hora', () => {
    const r = aplicarXp(inicio, 99);
    expect(r).toMatchObject({ nivel: 1, xp: 99, niveisGanhos: 0, pontosGanhos: 0 });
  });

  it('sobe exatamente no limite e zera o XP do nível', () => {
    const r = aplicarXp(inicio, 100);
    expect(r).toMatchObject({ nivel: 2, xp: 0, niveisGanhos: 1, pontosGanhos: 3, pontosDisponiveis: 3 });
  });

  it('sobe vários níveis de uma vez e guarda a sobra', () => {
    // 100 (1→2) + 150 (2→3) = 250; sobram 30
    const r = aplicarXp(inicio, 280);
    expect(r).toMatchObject({ nivel: 3, xp: 30, niveisGanhos: 2, pontosGanhos: 6 });
  });

  it('ao passar do 10 para o 11 ganha 2 pontos, não 3', () => {
    const r = aplicarXp({ nivel: 10, xp: 0, pontosDisponiveis: 0 }, 1700);
    expect(r).toMatchObject({ nivel: 11, pontosGanhos: 2 });
  });

  it('do 9 ao 11 de uma vez: 3 + 2 pontos', () => {
    const r = aplicarXp({ nivel: 9, xp: 0, pontosDisponiveis: 1 }, 1350 + 1700);
    expect(r).toMatchObject({ nivel: 11, xp: 0, pontosGanhos: 5, pontosDisponiveis: 6 });
  });

  it('aplica o xp_multiplier (gancho futuro) arredondando para baixo', () => {
    expect(aplicarXp(inicio, 45, 1.5).xpGanho).toBe(67);
    expect(aplicarXp(inicio, 45).xpGanho).toBe(45);
  });

  it('recusa XP negativo', () => {
    expect(() => aplicarXp(inicio, -1)).toThrow();
  });

  it('XP total acumulado', () => {
    expect(xpTotal(1, 50)).toBe(50);
    expect(xpTotal(3, 10)).toBe(100 + 150 + 10);
  });
});

describe('configuração vinda do banco', () => {
  it('usa os valores do game_config quando existem', () => {
    const cfg = montarConfig([
      { chave: 'xp.para_subir_ate_nivel_10', valor: [10, 20] },
      { chave: 'xp.incremento_apos_nivel_10', valor: 5 },
      { chave: 'xp.pontos_por_nivel', valor: { ate_nivel_10: 4, a_partir_nivel_11: 1 } },
    ]);
    expect(xpParaSubir(2, cfg)).toBe(20);
    expect(xpParaSubir(3, cfg)).toBe(25);
    expect(pontosAoAlcancar(5, cfg)).toBe(4);
    expect(pontosAoAlcancar(11, cfg)).toBe(1);
  });

  it('cai no padrão quando a chave falta ou vem estragada', () => {
    const cfg = montarConfig([{ chave: 'stamina.maxima', valor: 'abc' }]);
    expect(cfg.stamina.maxima).toBe(CONFIG_PADRAO.stamina.maxima);
    expect(montarConfig(null)).toEqual(CONFIG_PADRAO);
  });
});
