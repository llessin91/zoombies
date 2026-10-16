// tests/abrigo.test.ts — catch-up de produção, consumo e energia (depósito cheio, manutenção, combustível)
import { describe, expect, it } from 'vitest';
import {
  capacidadeDeposito,
  descreverDesvantagens,
  descreverVantagens,
  diasDeCombustivel,
  quantoCabe,
  simularAbrigo,
  type EstadoSim,
  type InstalacaoSim,
} from '@/lib/game/abrigo';

function inst(p: Partial<InstalacaoSim> & Pick<InstalacaoSim, 'id' | 'item' | 'cicloDias'>): InstalacaoSim {
  return { qtd: 1, consumoEnergia: 0, progressoDias: 0, ciclos: 0, acumulada: 0, parada: false, ...p };
}

function abrigo(p: Partial<EstadoSim> = {}): EstadoSim {
  return { deposito: {}, capacidade: 100, gerador: null, painelSolar: 0, combustivelProgresso: 0, recrutas: 0, instalacoes: [], ...p };
}

describe('produção passiva', () => {
  it('captação de água: 1 por dia do jogo', () => {
    const r = simularAbrigo(abrigo({ instalacoes: [inst({ id: 'a', item: 'agua_potavel', cicloDias: 1 })] }), 5);
    expect(r.estado.instalacoes[0].acumulada).toBe(5);
  });
  it('horta: 1 a cada 2 dias, guardando o meio do ciclo', () => {
    const r = simularAbrigo(abrigo({ instalacoes: [inst({ id: 'h', item: 'comida_enlatada', cicloDias: 2 })] }), 5);
    expect(r.estado.instalacoes[0].acumulada).toBe(2);
    expect(r.estado.instalacoes[0].progressoDias).toBe(1);
  });
  it('instalação que ficou pronta no meio do período só produz depois de pronta', () => {
    // pronta 2 dias depois da última visita: começa em -2
    const r = simularAbrigo(abrigo({ instalacoes: [inst({ id: 'a', item: 'agua_potavel', cicloDias: 1, progressoDias: -2 })] }), 5);
    expect(r.estado.instalacoes[0].acumulada).toBe(3);
  });
  it('produção limitada a 30 dias por consulta', () => {
    const r = simularAbrigo(abrigo({ instalacoes: [inst({ id: 'a', item: 'agua_potavel', cicloDias: 1 })] }), 90);
    expect(r.estado.instalacoes[0].acumulada).toBe(30);
  });
});

describe('depósito cheio', () => {
  it('a produção para quando o depósito enche (o acumulado conta)', () => {
    const r = simularAbrigo(abrigo({ capacidade: 10, deposito: { madeira: 7 }, instalacoes: [inst({ id: 'a', item: 'agua_potavel', cicloDias: 1 })] }), 10);
    expect(r.estado.instalacoes[0].acumulada).toBe(3);
  });
  it('quanto cabe respeita o peso', () => {
    expect(quantoCabe(5, 2, 7)).toBe(3);
    expect(quantoCabe(5, 0, 0)).toBe(5);
    expect(quantoCabe(5, 1, -3)).toBe(0);
  });
  it('capacidade = base + Depósitos construídos', () => {
    expect(capacidadeDeposito(100, [50])).toBe(150);
  });
});

describe('manutenção', () => {
  const galinheiro = () =>
    inst({ id: 'g', item: 'comida_enlatada', cicloDias: 1, manutencao: { itens: { comida_enlatada: 1 }, aCadaCiclos: 5 } });

  it('paga a manutenção a cada 5 ciclos', () => {
    const r = simularAbrigo(abrigo({ deposito: { comida_enlatada: 2 }, instalacoes: [galinheiro()] }), 10);
    // 10 ciclos, 2 manutenções pagas, 10 produzidos
    expect(r.estado.deposito.comida_enlatada).toBe(0);
    expect(r.estado.instalacoes[0].acumulada).toBe(10);
    expect(r.estado.instalacoes[0].parada).toBe(false);
  });
  it('sem o item da manutenção, para de produzir', () => {
    const r = simularAbrigo(abrigo({ deposito: {}, instalacoes: [galinheiro()] }), 7);
    // produz 4 ciclos, falha no 5º; nos dias 6 e 7 volta a produzir (falha só nos ciclos de manutenção)
    expect(r.estado.instalacoes[0].acumulada).toBe(6);
    expect(r.estado.instalacoes[0].ciclos).toBe(7);
  });
  it('fica parada no ciclo de manutenção não paga', () => {
    const r = simularAbrigo(abrigo({ deposito: {}, instalacoes: [galinheiro()] }), 5);
    expect(r.estado.instalacoes[0].parada).toBe(true);
  });
});

describe('energia e combustível', () => {
  const gerador = { cobre: 3, diasPorCombustivel: 5 };
  const enfermaria = () => inst({ id: 'e', item: 'nada', qtd: 0, cicloDias: 999, consumoEnergia: 1 });

  it('gerador gasta 1 combustível a cada 5 dias', () => {
    const r = simularAbrigo(abrigo({ gerador, deposito: { combustivel: 3 } }), 12);
    expect(r.combustivelGasto).toBe(2);
    expect(r.estado.deposito.combustivel).toBe(1);
    expect(r.energiaOk).toBe(true);
  });
  it('sem combustível o gerador para e a energia some', () => {
    const r = simularAbrigo(abrigo({ gerador, deposito: { combustivel: 2 }, instalacoes: [enfermaria()] }), 18);
    expect(r.combustivelGasto).toBe(2);
    expect(r.energiaOk).toBe(false);
  });
  it('consumo de combustível continua além dos 30 dias de produção', () => {
    const r = simularAbrigo(abrigo({ gerador, deposito: { combustivel: 20 } }), 60);
    expect(r.combustivelGasto).toBe(12);
  });
  it('instalação elétrica sem energia não produz', () => {
    const destilaria = inst({ id: 'd', item: 'combustivel', cicloDias: 5, consumoEnergia: 1 });
    const sem = simularAbrigo(abrigo({ instalacoes: [destilaria] }), 10);
    expect(sem.estado.instalacoes[0].acumulada).toBe(0);
    const com = simularAbrigo(abrigo({ painelSolar: 2, instalacoes: [destilaria] }), 10);
    expect(com.estado.instalacoes[0].acumulada).toBe(2);
  });
  it('painel solar funciona sem combustível', () => {
    const r = simularAbrigo(abrigo({ painelSolar: 2, instalacoes: [enfermaria()] }), 30);
    expect(r.energiaOk).toBe(true);
  });
  it('recrutas contam na demanda (Fase 8)', () => {
    const r = simularAbrigo(abrigo({ gerador, deposito: { combustivel: 5 }, recrutas: 4 }), 2);
    expect(r.energiaOk).toBe(false);
  });
  it('previsão de dias de combustível', () => {
    expect(diasDeCombustivel(2, 5, 2)).toBe(13);
    expect(diasDeCombustivel(0, 5, 5)).toBe(0);
    expect(diasDeCombustivel(3, null, 0)).toBeNull();
  });
});

describe('textos da escolha do abrigo', () => {
  it('mostra os números das vantagens e desvantagens', () => {
    expect(descreverVantagens({ stamina_max_bonus_pct: 10 })).toEqual(['+10% de stamina máxima']);
    expect(descreverDesvantagens({ custo_stamina_saida_extra: 1 })[0]).toMatch(/\+1 de stamina/);
  });
});
