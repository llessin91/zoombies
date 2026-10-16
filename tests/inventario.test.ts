// tests/inventario.test.ts — usar, equipar, descartar, filtros, busca e peso
import { describe, expect, it } from 'vitest';
import {
  ferimentosDepoisDeUsar,
  filtrarItens,
  motivoNaoDescartar,
  motivoNaoEquipar,
  motivoNaoUsar,
  normalizar,
  pesoDosItens,
  slotDaArma,
  staminaDepoisDeUsar,
} from '@/lib/game/inventario';

const base = { staminaAtual: 10, staminaMaxima: 20, ferimentos: 0 };

describe('usar itens', () => {
  it('água, comida e ração recuperam stamina sem passar do máximo', () => {
    expect(motivoNaoUsar({ ...base, tipo: 'consumivel', slug: 'agua_potavel', recuperaStamina: 1 })).toBeNull();
    expect(staminaDepoisDeUsar(19, 20, 3)).toBe(20);
    expect(staminaDepoisDeUsar(10, 20, 2)).toBe(12);
  });
  it('com stamina cheia não dá para comer', () => {
    expect(motivoNaoUsar({ ...base, staminaAtual: 20, tipo: 'consumivel', slug: 'comida_enlatada', recuperaStamina: 2 })).toMatch(/cheia/);
  });
  it('bandagem e kit curam ferimentos, nunca abaixo de zero', () => {
    expect(motivoNaoUsar({ ...base, ferimentos: 2, tipo: 'consumivel', slug: 'bandagem', curaFerimento: 1 })).toBeNull();
    expect(ferimentosDepoisDeUsar(2, 1)).toBe(1);
    expect(ferimentosDepoisDeUsar(1, 2)).toBe(0);
  });
  it('sem ferimento não gasta bandagem', () => {
    expect(motivoNaoUsar({ ...base, tipo: 'consumivel', slug: 'bandagem', curaFerimento: 1 })).toMatch(/não está ferido/);
  });
  it('recursos, armas e itens-chave não são "usados"', () => {
    expect(motivoNaoUsar({ ...base, tipo: 'recurso', slug: 'madeira' })).toMatch(/construir/);
    expect(motivoNaoUsar({ ...base, tipo: 'arma', slug: 'glock_17' })).toMatch(/equipadas/);
    expect(motivoNaoUsar({ ...base, tipo: 'item_chave', slug: 'credencial_industrial' })).toMatch(/sozinhos/);
  });
  it('consumível sem efeito de uso direto (ex.: molotov) fica bloqueado', () => {
    expect(motivoNaoUsar({ ...base, tipo: 'consumivel', slug: 'molotov' })).not.toBeNull();
  });
});

describe('equipar', () => {
  it('corpo a corpo vai no slot próprio; o resto é arma principal', () => {
    expect(slotDaArma('corpo_a_corpo')).toBe('arma_corpo_a_corpo');
    expect(slotDaArma('pistola')).toBe('arma_principal');
    expect(slotDaArma('rifle_precisao')).toBe('arma_principal');
  });
  it('recusa arma quebrada, de nível alto e o que não é arma', () => {
    expect(motivoNaoEquipar({ tipo: 'arma', durabilidade: 0, nivel_requisito: 1 }, 5)).toMatch(/quebrada/);
    expect(motivoNaoEquipar({ tipo: 'arma', durabilidade: 50, nivel_requisito: 12 }, 5)).toMatch(/nível 12/);
    expect(motivoNaoEquipar({ tipo: 'recurso', durabilidade: null, nivel_requisito: 1 }, 5)).toMatch(/Só armas/);
    expect(motivoNaoEquipar({ tipo: 'arma', durabilidade: 50, nivel_requisito: 1 }, 1)).toBeNull();
  });
});

describe('descartar', () => {
  const item = { tipo: 'recurso', equipado: null, em_expedicao: false };
  it('aceita quantidade entre 1 e o que tem', () => {
    expect(motivoNaoDescartar(item, 2, 3)).toBeNull();
    expect(motivoNaoDescartar(item, 3, 3)).toBeNull();
  });
  it('recusa zero, negativo, quebrado e mais do que tem', () => {
    expect(motivoNaoDescartar(item, 0, 3)).toMatch(/inválida/);
    expect(motivoNaoDescartar(item, -1, 3)).toMatch(/inválida/);
    expect(motivoNaoDescartar(item, 1.5, 3)).toMatch(/inválida/);
    expect(motivoNaoDescartar(item, 4, 3)).toMatch(/inválida/);
  });
  it('protege itens-chave, armas equipadas e armas em expedição', () => {
    expect(motivoNaoDescartar({ ...item, tipo: 'item_chave' }, 1, 1)).toMatch(/Itens-chave/);
    expect(motivoNaoDescartar({ ...item, tipo: 'arma', equipado: 'arma_principal' }, 1, 1)).toMatch(/Desequipe/);
    expect(motivoNaoDescartar({ ...item, tipo: 'arma', em_expedicao: true }, 1, 1)).toMatch(/expedição/);
  });
});

describe('filtros, busca e peso', () => {
  const itens = [
    { tipo: 'recurso', nome: 'Madeira', descricao: 'Tábuas', peso: 1, quantidade: 4 },
    { tipo: 'consumivel', nome: 'Água potável', descricao: 'Limpa', peso: 1, quantidade: 2 },
    { tipo: 'arma', nome: 'Facão', descricao: 'Ferramenta de mato', peso: 2, quantidade: 1 },
    { tipo: 'item_chave', nome: 'Credencial industrial', descricao: 'Abre portões', peso: 0, quantidade: 1 },
  ];
  it('filtra por tipo', () => {
    expect(filtrarItens(itens, 'arma', '')).toHaveLength(1);
    expect(filtrarItens(itens, 'todos', '')).toHaveLength(4);
    expect(filtrarItens(itens, 'outros', '')).toHaveLength(0);
  });
  it('busca ignora acentos e maiúsculas, e procura na descrição', () => {
    expect(filtrarItens(itens, 'todos', 'AGUA')[0].nome).toBe('Água potável');
    expect(filtrarItens(itens, 'todos', 'facao')).toHaveLength(1);
    expect(filtrarItens(itens, 'todos', 'portões')).toHaveLength(1);
    expect(normalizar('  Ação ')).toBe('acao');
  });
  it('soma peso × quantidade', () => {
    expect(pesoDosItens(itens)).toBe(4 + 2 + 2 + 0);
    expect(pesoDosItens([{ peso: 0.5, quantidade: 3 }])).toBe(1.5);
  });
});
