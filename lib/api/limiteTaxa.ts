// src/lib/api/limiteTaxa.ts
// Limite de pedidos simples por usuário (janela deslizante em memória).
// Na Vercel cada servidor tem a sua memória, então o limite é aproximado. Serve para
// barrar cliques repetidos e scripts bobos; a proteção de verdade (stamina, pontos,
// travas de linha) está no banco.

const registros = new Map<string, number[]>();

export function dentroDoLimite(chave: string, maximo: number, janelaMs: number, agora = Date.now()): boolean {
  const recentes = (registros.get(chave) ?? []).filter((t) => agora - t < janelaMs);
  if (recentes.length >= maximo) {
    registros.set(chave, recentes);
    return false;
  }
  recentes.push(agora);
  registros.set(chave, recentes);

  // Limpeza para a memória não crescer para sempre
  if (registros.size > 5000) {
    registros.forEach((lista, k) => {
      if (lista.every((t) => agora - t >= janelaMs)) registros.delete(k);
    });
  }
  return true;
}

/** Só para testes */
export function limparLimites() {
  registros.clear();
}
