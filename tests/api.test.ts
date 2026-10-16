// tests/api.test.ts — limite de pedidos e mensagens de erro (sem vazar detalhes internos)
import { beforeEach, describe, expect, it } from 'vitest';
import { dentroDoLimite, limparLimites } from '@/lib/api/limiteTaxa';
import { mensagemErroBanco } from '@/lib/api/erros';

describe('limite de pedidos', () => {
  beforeEach(() => limparLimites());

  it('bloqueia depois do máximo dentro da janela', () => {
    const t = 1_000_000;
    for (let i = 0; i < 3; i++) expect(dentroDoLimite('a', 3, 10_000, t + i)).toBe(true);
    expect(dentroDoLimite('a', 3, 10_000, t + 5)).toBe(false);
  });

  it('libera de novo quando a janela passa', () => {
    const t = 1_000_000;
    for (let i = 0; i < 3; i++) dentroDoLimite('a', 3, 10_000, t);
    expect(dentroDoLimite('a', 3, 10_000, t + 10_001)).toBe(true);
  });

  it('cada jogador tem o próprio limite', () => {
    const t = 1_000_000;
    for (let i = 0; i < 3; i++) dentroDoLimite('usuario-a', 3, 10_000, t);
    expect(dentroDoLimite('usuario-a', 3, 10_000, t)).toBe(false);
    expect(dentroDoLimite('usuario-b', 3, 10_000, t)).toBe(true);
  });
});

describe('mensagens de erro do banco', () => {
  it('repassa as mensagens do próprio jogo (RAISE)', () => {
    expect(mensagemErroBanco({ code: 'P0001', message: 'Stamina insuficiente.' })).toEqual({ mensagem: 'Stamina insuficiente.', status: 400 });
  });
  it('esconde erros internos', () => {
    const r = mensagemErroBanco({ code: '23505', message: 'duplicate key value violates unique constraint "characters_user_id_key"' });
    expect(r.mensagem).not.toMatch(/duplicate|constraint|characters/);
    expect(r.status).toBe(500);
  });
  it('avisa quando falta rodar o SQL da fase', () => {
    expect(mensagemErroBanco({ code: 'PGRST202' }).mensagem).toMatch(/README/);
  });
  it('permissão negada vira 403', () => {
    expect(mensagemErroBanco({ code: '42501', message: 'permission denied for function conceder_xp' })).toEqual({ mensagem: 'Ação não permitida.', status: 403 });
  });
});
