// src/lib/api/cliente.ts
// Usado no navegador para pedir ações ao servidor. Nunca decide nada: só envia e mostra a resposta.

export type RespostaAcao<T> = { ok: true; dados: T } | { ok: false; erro: string };

export async function pedirAcao<T = unknown>(caminho: string, corpo?: unknown): Promise<RespostaAcao<T>> {
  try {
    const r = await fetch(caminho, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: corpo === undefined ? undefined : JSON.stringify(corpo),
      cache: 'no-store',
    });
    const json = (await r.json().catch(() => null)) as ({ ok?: boolean; erro?: string } & Record<string, unknown>) | null;
    if (!r.ok || !json?.ok) return { ok: false, erro: json?.erro ?? 'Sem resposta do servidor. Tente de novo.' };
    return { ok: true, dados: json as T };
  } catch {
    return { ok: false, erro: 'Sem conexão. Confira a internet e tente de novo.' };
  }
}
