// tests/expedicao.test.ts — desfecho, saque, XP, carga, ferimento, arma, evento e barra de progresso
import { describe, expect, it } from 'vitest';
import {
  aplicarPerda,
  cargaDisponivel,
  chanceFerimento,
  classificarDesfecho,
  durabilidadeDepois,
  lerEstadoExpedicao,
  opcaoCautelosa,
  pesoTotal,
  progressoExpedicao,
  quantidadeLoot,
  validarEscolhaLoot,
  xpDoDesfecho,
} from '@/lib/game/expedicao';

describe('desfecho da missão', () => {
  it('rolagem até P = sucesso total', () => {
    expect(classificarDesfecho(1, 50)).toBe('total');
    expect(classificarDesfecho(50, 50)).toBe('total');
  });
  it('até P + 15 = sucesso parcial', () => {
    expect(classificarDesfecho(51, 50)).toBe('parcial');
    expect(classificarDesfecho(65, 50)).toBe('parcial');
  });
  it('acima = fracasso', () => {
    expect(classificarDesfecho(66, 50)).toBe('fracasso');
  });
  it('com P = 95 ainda existe fracasso possível (rolagem 100 não cabe se margem pequena)', () => {
    expect(classificarDesfecho(100, 95, 4)).toBe('fracasso');
  });
});

describe('saque e XP', () => {
  it('parcial dá metade (arredonda para baixo), fracasso dá nada', () => {
    expect(quantidadeLoot(4, 'total')).toBe(4);
    expect(quantidadeLoot(3, 'parcial')).toBe(1);
    expect(quantidadeLoot(1, 'parcial')).toBe(0);
    expect(quantidadeLoot(9, 'fracasso')).toBe(0);
  });
  it('XP: 100% / 50% / 15% mais bônus do evento', () => {
    expect(xpDoDesfecho(90, 'total')).toBe(90);
    expect(xpDoDesfecho(90, 'parcial')).toBe(45);
    expect(xpDoDesfecho(90, 'fracasso')).toBe(13);
    expect(xpDoDesfecho(20, 'total', 10)).toBe(30);
  });
  it('perda do evento (vazamento 30%)', () => {
    expect(aplicarPerda(10, 30)).toBe(7);
    expect(aplicarPerda(1, 30)).toBe(0);
  });
});

describe('carga e "o que levar"', () => {
  const saque = [
    { item: 'madeira', qtd: 4, peso: 1 },
    { item: 'metal', qtd: 2, peso: 2 },
  ];
  it('peso total e capacidade', () => {
    expect(pesoTotal(saque)).toBe(8);
    expect(cargaDisponivel(12, 2)).toBe(10);
    expect(cargaDisponivel(1, 5)).toBe(0);
  });
  it('escolha dentro da capacidade é aceita', () => {
    expect(validarEscolhaLoot(saque, { madeira: 2, metal: 1 }, 4)).toBeNull();
  });
  it('escolha pesada demais é recusada', () => {
    expect(validarEscolhaLoot(saque, { madeira: 4, metal: 2 }, 6)).toMatch(/pesado/);
  });
  it('não dá para levar mais do que achou nem quantidade negativa', () => {
    expect(validarEscolhaLoot(saque, { madeira: 5 }, 99)).toMatch(/inválida/);
    expect(validarEscolhaLoot(saque, { madeira: -1 }, 99)).toMatch(/inválida/);
  });
  it('deixar tudo para trás é permitido', () => {
    expect(validarEscolhaLoot(saque, {}, 0)).toBeNull();
  });
});

describe('ferimento e arma', () => {
  it('bandagem e kit reduzem a chance, sem ficar negativa', () => {
    const red = { bandagem: 20, kit_primeiros_socorros: 40 };
    expect(chanceFerimento(40, [], red)).toBe(40);
    expect(chanceFerimento(40, [{ item: 'bandagem', qtd: 1 }], red)).toBe(20);
    expect(chanceFerimento(40, [{ item: 'kit_primeiros_socorros', qtd: 2 }], red)).toBe(0);
  });
  it('arma gasta mais no fracasso e não fica negativa', () => {
    expect(durabilidadeDepois(60, 2, 'total')).toBe(58);
    expect(durabilidadeDepois(60, 2, 'fracasso')).toBe(56);
    expect(durabilidadeDepois(3, 8, 'fracasso')).toBe(0);
  });
});

describe('evento sem resposta em 24 h', () => {
  it('aplica a opção marcada como cautelosa', () => {
    expect(opcaoCautelosa([{ indice: 0, risco: 2 }, { indice: 1, risco: 3 }, { indice: 2, risco: 1, cautelosa: true }])).toBe(2);
  });
  it('nunca escolhe opção com requisito ou custo', () => {
    expect(opcaoCautelosa([{ indice: 0, risco: 1, temCusto: true }, { indice: 1, risco: 3 }])).toBe(1);
  });
  it('sem marcação, pega a de menor risco', () => {
    expect(opcaoCautelosa([{ indice: 0, risco: 3 }, { indice: 1, risco: 1 }])).toBe(1);
  });
});

describe('barra de progresso', () => {
  const base = { iniciadaMs: 0, duracaoSeg: 60, pausaSeg: 0, eventoEm: null, eventoResolvido: false, aguardandoEvento: false };
  it('avança com o tempo e para no fim', () => {
    expect(progressoExpedicao({ ...base, agoraMs: 30_000 })).toBe(0.5);
    expect(progressoExpedicao({ ...base, agoraMs: 999_000 })).toBe(1);
  });
  it('não passa do marcador enquanto o evento não foi decidido', () => {
    expect(progressoExpedicao({ ...base, eventoEm: 0.4, agoraMs: 50_000 })).toBe(0.4);
  });
  it('fica parada no evento durante a decisão', () => {
    expect(progressoExpedicao({ ...base, eventoEm: 0.4, aguardandoEvento: true, agoraMs: 999_000 })).toBe(0.4);
  });
  it('depois da decisão, desconta o tempo parado', () => {
    // 24 s até o evento + 100 s decidindo + 6 s andando = 30 s de caminhada
    expect(progressoExpedicao({ ...base, eventoEm: 0.4, eventoResolvido: true, pausaSeg: 100, agoraMs: 130_000 })).toBe(0.5);
  });
});

describe('estado vindo do banco', () => {
  it('lê uma expedição concluída sem números de cálculo', () => {
    const e = lerEstadoExpedicao({
      id: 'x', estado: 'concluida',
      missao: { slug: 's', nome: 'N', dificuldade: 'facil', categoria: 'exploracao', regiao: 'periferia', local: 'L', ponto: null },
      iniciada_em: '2026-01-01T00:00:00Z', termina_em: '2026-01-01T00:00:30Z', duracao_seg: 30, pausa_seg: 0,
      evento_em: null, evento_aberto_em: null, evento_resolvido: false, tem_evento: false, evento: null,
      log: [{ pct: 0, texto: 'a' }], custo_stamina: 2, carga_max: 24, peso_levado: 0,
      resultado: {
        desfecho: 'total', texto: 't', loot: [{ item: 'madeira', qtd: 2, nome: 'Madeira', tipo: 'recurso', raridade: 'comum', peso: '1.00' }],
        peso_loot: 2, carga_disponivel: 24, excesso: false, xp_ganho: 20, niveis_ganhos: 0, moral: 2, ferido: false, ferimentos: 0,
        stamina_gasta: 2, arma_durabilidade: null, zumbis: 1, recruta_encontrado: false, evento: null,
      },
      loot_entregue: true, servidor_agora: '2026-01-01T00:01:00Z',
    });
    expect(e.resultado?.loot[0].peso).toBe(1);
    expect(JSON.stringify(e)).not.toMatch(/auditoria|rolagem/);
  });
});
