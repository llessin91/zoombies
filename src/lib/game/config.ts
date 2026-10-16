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
}

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
};

type LinhaConfig = { chave: string; valor: unknown };

function numero(v: unknown, reserva: number): number {
  const n = typeof v === 'string' ? Number(v) : v;
  return typeof n === 'number' && Number.isFinite(n) ? n : reserva;
}

/** Junta as linhas da tabela game_config por cima dos valores padrão */
export function montarConfig(linhas: LinhaConfig[] | null | undefined): ConfigJogo {
  const mapa = new Map((linhas ?? []).map((l) => [l.chave, l.valor]));
  const p = CONFIG_PADRAO;
  const pontos = (mapa.get('xp.pontos_por_nivel') ?? {}) as Record<string, unknown>;
  const lista = mapa.get('xp.para_subir_ate_nivel_10');

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
  };
}
