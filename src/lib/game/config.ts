// src/lib/game/config.ts
// Valores PROVISÓRIOS de balanceamento usados pelas regras em TypeScript.
//
// A fonte oficial é a tabela game_config no Supabase (o servidor do jogo lê de lá).
// Este arquivo guarda os MESMOS valores padrão, usados nos testes e como reserva.
// Se você mudar um número no Supabase, o jogo usa o do Supabase.

export interface ConfigJogo {
  tempo: { diasJogoPorHoraReal: number; horaInicial: number };
  stamina: { inicial: number; maxima: number; minutosPorPonto: number };
  atributos: { pontosNaCriacao: number; minimoNaCriacao: number; maximoNaCriacao: number; maximo: number };
  moral: { inicial: number; divisorModificador: number; bonusSucessoFacil: number };
  xp: {
    paraSubirAteNivel10: number[];
    incrementoAposNivel10: number;
    pontosAteLimite: number;
    pontosDepoisLimite: number;
    ultimoNivelComMaisPontos: number;
  };
  missao: {
    formula: { base: number; pesoDiferenca: number; minimo: number; maximo: number };
    dificuldadeNumerica: PorDificuldade;
    custoStamina: PorDificuldade;
    duracaoSegundos: PorDificuldade;
    xpBase: PorDificuldade;
    cooldownLocalDias: PorDificuldade;
    /** Chance mínima de cada faixa (o número nunca aparece para o jogador) */
    faixas: { segura: number; equilibrada: number; arriscada: number };
  };
  carga: { base: number; porPontoForca: number };
}

export type Dificuldade = 'facil' | 'media' | 'dificil' | 'lendaria';
export type PorDificuldade = Record<Dificuldade, number>;

export const CONFIG_PADRAO: ConfigJogo = {
  tempo: { diasJogoPorHoraReal: 1, horaInicial: 8 },
  stamina: { inicial: 20, maxima: 20, minutosPorPonto: 6 },
  atributos: { pontosNaCriacao: 12, minimoNaCriacao: 1, maximoNaCriacao: 3, maximo: 20 },
  moral: { inicial: 70, divisorModificador: 10, bonusSucessoFacil: 2 },
  xp: {
    paraSubirAteNivel10: [100, 150, 220, 320, 450, 600, 800, 1050, 1350],
    incrementoAposNivel10: 350,
    pontosAteLimite: 3,
    pontosDepoisLimite: 2,
    ultimoNivelComMaisPontos: 10,
  },
  missao: {
    formula: { base: 50, pesoDiferenca: 5, minimo: 5, maximo: 95 },
    dificuldadeNumerica: { facil: 3, media: 6, dificil: 10, lendaria: 14 },
    custoStamina: { facil: 2, media: 3, dificil: 5, lendaria: 6 },
    duracaoSegundos: { facil: 30, media: 60, dificil: 90, lendaria: 120 },
    xpBase: { facil: 20, media: 45, dificil: 90, lendaria: 160 },
    cooldownLocalDias: { facil: 3, media: 5, dificil: 8, lendaria: 12 },
    faixas: { segura: 70, equilibrada: 45, arriscada: 25 },
  },
  carga: { base: 10, porPontoForca: 2 },
};

type LinhaConfig = { chave: string; valor: unknown };

function numero(v: unknown, reserva: number): number {
  const n = typeof v === 'string' ? Number(v) : v;
  return typeof n === 'number' && Number.isFinite(n) ? n : reserva;
}

function porDificuldade(v: unknown, reserva: PorDificuldade): PorDificuldade {
  const o = (v ?? {}) as Record<string, unknown>;
  return {
    facil: numero(o.facil, reserva.facil),
    media: numero(o.media, reserva.media),
    dificil: numero(o.dificil, reserva.dificil),
    lendaria: numero(o.lendaria, reserva.lendaria),
  };
}

/** Junta as linhas da tabela game_config por cima dos valores padrão */
export function montarConfig(linhas: LinhaConfig[] | null | undefined): ConfigJogo {
  const mapa = new Map((linhas ?? []).map((l) => [l.chave, l.valor]));
  const p = CONFIG_PADRAO;
  const pontos = (mapa.get('xp.pontos_por_nivel') ?? {}) as Record<string, unknown>;
  const lista = mapa.get('xp.para_subir_ate_nivel_10');
  const formula = (mapa.get('missao.formula') ?? {}) as Record<string, unknown>;
  const faixas = (mapa.get('missao.faixas_chance') ?? {}) as Record<string, unknown>;

  return {
    tempo: {
      diasJogoPorHoraReal: numero(mapa.get('tempo.dias_jogo_por_hora_real'), p.tempo.diasJogoPorHoraReal),
      horaInicial: numero(mapa.get('tempo.hora_inicial'), p.tempo.horaInicial),
    },
    stamina: {
      inicial: numero(mapa.get('stamina.inicial'), p.stamina.inicial),
      maxima: numero(mapa.get('stamina.maxima'), p.stamina.maxima),
      minutosPorPonto: numero(mapa.get('stamina.minutos_por_ponto'), p.stamina.minutosPorPonto),
    },
    atributos: {
      pontosNaCriacao: numero(mapa.get('atributos.pontos_na_criacao'), p.atributos.pontosNaCriacao),
      minimoNaCriacao: numero(mapa.get('atributos.minimo_na_criacao'), p.atributos.minimoNaCriacao),
      maximoNaCriacao: numero(mapa.get('atributos.maximo_na_criacao'), p.atributos.maximoNaCriacao),
      maximo: numero(mapa.get('atributos.maximo'), p.atributos.maximo),
    },
    moral: {
      inicial: numero(mapa.get('moral.inicial'), p.moral.inicial),
      divisorModificador: numero(mapa.get('moral.divisor_modificador'), p.moral.divisorModificador),
      bonusSucessoFacil: numero(mapa.get('moral.bonus_sucesso_facil'), p.moral.bonusSucessoFacil),
    },
    xp: {
      paraSubirAteNivel10:
        Array.isArray(lista) && lista.length > 0 ? lista.map((v, i) => numero(v, p.xp.paraSubirAteNivel10[i] ?? 0)) : p.xp.paraSubirAteNivel10,
      incrementoAposNivel10: numero(mapa.get('xp.incremento_apos_nivel_10'), p.xp.incrementoAposNivel10),
      pontosAteLimite: numero(pontos.ate_nivel_10, p.xp.pontosAteLimite),
      pontosDepoisLimite: numero(pontos.a_partir_nivel_11, p.xp.pontosDepoisLimite),
      ultimoNivelComMaisPontos: numero(mapa.get('xp.ultimo_nivel_com_mais_pontos'), p.xp.ultimoNivelComMaisPontos),
    },
    missao: {
      formula: {
        base: numero(formula.base, p.missao.formula.base),
        pesoDiferenca: numero(formula.peso_diferenca, p.missao.formula.pesoDiferenca),
        minimo: numero(formula.minimo, p.missao.formula.minimo),
        maximo: numero(formula.maximo, p.missao.formula.maximo),
      },
      dificuldadeNumerica: porDificuldade(mapa.get('missao.dificuldade_numerica'), p.missao.dificuldadeNumerica),
      custoStamina: porDificuldade(mapa.get('stamina.custo_por_dificuldade'), p.missao.custoStamina),
      duracaoSegundos: porDificuldade(mapa.get('missao.duracao_segundos'), p.missao.duracaoSegundos),
      xpBase: porDificuldade(mapa.get('missao.xp_base'), p.missao.xpBase),
      cooldownLocalDias: porDificuldade(mapa.get('missao.cooldown_local_dias'), p.missao.cooldownLocalDias),
      faixas: {
        segura: numero(faixas.segura, p.missao.faixas.segura),
        equilibrada: numero(faixas.equilibrada, p.missao.faixas.equilibrada),
        arriscada: numero(faixas.arriscada, p.missao.faixas.arriscada),
      },
    },
    carga: {
      base: numero(mapa.get('carga.base'), p.carga.base),
      porPontoForca: numero(mapa.get('carga.por_ponto_forca'), p.carga.porPontoForca),
    },
  };
}
