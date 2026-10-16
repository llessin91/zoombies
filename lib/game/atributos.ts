// src/lib/game/atributos.ts
// Os seis atributos do sobrevivente: nome, descrição curta e para que servem.

export const CHAVES_ATRIBUTOS = ['forca', 'agilidade', 'percepcao', 'medicina', 'engenharia', 'lideranca'] as const;
export type ChaveAtributo = (typeof CHAVES_ATRIBUTOS)[number];
export type Atributos = Record<ChaveAtributo, number>;

export interface InfoAtributo {
  chave: ChaveAtributo;
  nome: string;
  curta: string;
  usos: string;
}

export const ATRIBUTOS: InfoAtributo[] = [
  {
    chave: 'forca',
    nome: 'Força',
    curta: 'Bater, carregar e aguentar.',
    usos: 'Dano corpo a corpo, carga, arrombar, resistência a ferimentos e menos stamina em ações físicas.',
  },
  {
    chave: 'agilidade',
    nome: 'Agilidade',
    curta: 'Fugir antes de virar almoço.',
    usos: 'Esquiva e fuga, velocidade, evitar armadilhas, furtividade e menos stamina em movimento.',
  },
  {
    chave: 'percepcao',
    nome: 'Percepção',
    curta: 'Ver o perigo (e o saque) primeiro.',
    usos: 'Detectar perigos e loot, achar itens raros e precisão à distância.',
  },
  {
    chave: 'medicina',
    nome: 'Medicina',
    curta: 'Remendar gente, inclusive você.',
    usos: 'Cura, infecção, remédios, ferimentos e atender sobreviventes feridos.',
  },
  {
    chave: 'engenharia',
    nome: 'Engenharia',
    curta: 'Fazer muito com sucata.',
    usos: 'Fabricar e reparar, construir com menos recursos, armadilhas, fechaduras, geradores e produção.',
  },
  {
    chave: 'lideranca',
    nome: 'Liderança',
    curta: 'Convencer os outros a não desistir.',
    usos: 'Comunidade, recrutamento, moral do grupo, negociação e menos consumo dos recrutas.',
  },
];

export function atributosZerados(): Atributos {
  return { forca: 0, agilidade: 0, percepcao: 0, medicina: 0, engenharia: 0, lideranca: 0 };
}

export function somaAtributos(a: Atributos): number {
  return CHAVES_ATRIBUTOS.reduce((s, k) => s + a[k], 0);
}

export interface LimitesCriacao {
  total: number;
  minimo: number;
  maximo: number;
}

/** Mesma regra do SQL criar_personagem: cada um entre mínimo e máximo, soma exata */
export function validarCriacao(a: Atributos, l: LimitesCriacao): string | null {
  for (const k of CHAVES_ATRIBUTOS) {
    if (!Number.isInteger(a[k]) || a[k] < l.minimo || a[k] > l.maximo) return `Cada atributo deve ficar entre ${l.minimo} e ${l.maximo}.`;
  }
  const soma = somaAtributos(a);
  if (soma !== l.total) return `Distribua exatamente ${l.total} pontos.`;
  return null;
}

/** Mesma regra do SQL distribuir_pontos */
export function validarDistribuicao(base: Atributos, extra: Atributos, pontosDisponiveis: number, maximo: number): string | null {
  let soma = 0;
  for (const k of CHAVES_ATRIBUTOS) {
    if (!Number.isInteger(extra[k]) || extra[k] < 0) return 'Valores inválidos.';
    if (base[k] + extra[k] > maximo) return `Nenhum atributo pode passar de ${maximo}.`;
    soma += extra[k];
  }
  if (soma === 0) return 'Escolha pelo menos 1 ponto.';
  if (soma > pontosDisponiveis) return 'Você não tem pontos suficientes.';
  return null;
}
