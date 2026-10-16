'use client';

// src/components/game/FormularioCriacao.tsx
// Criação do personagem: distribuir os pontos iniciais entre os seis atributos.
// A tela ajuda (contador, limites), mas quem aceita ou recusa é o servidor.

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Minus, Plus } from 'lucide-react';
import { Botao } from '@/components/ui/Botao';
import { Cartao } from '@/components/ui/Cartao';
import { Selo } from '@/components/ui/Selo';
import { useToast } from '@/components/ui/Toast';
import { pedirAcao } from '@/lib/api/cliente';
import { ATRIBUTOS, CHAVES_ATRIBUTOS, somaAtributos, validarCriacao, type Atributos, type ChaveAtributo, type LimitesCriacao } from '@/lib/game/atributos';
import { cn } from '@/lib/utils';
import { IconeAtributo } from './IconeAtributo';

function inicial(minimo: number): Atributos {
  return Object.fromEntries(CHAVES_ATRIBUTOS.map((k) => [k, minimo])) as Atributos;
}

const BOTAO_PASSO =
  'flex h-11 w-11 items-center justify-center rounded-md border focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde';

export function FormularioCriacao({ nome, limites }: { nome: string; limites: LimitesCriacao }) {
  const router = useRouter();
  const toast = useToast();
  const [valores, setValores] = useState<Atributos>(() => inicial(limites.minimo));
  const [enviando, setEnviando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);

  const restantes = limites.total - somaAtributos(valores);
  const problema = validarCriacao(valores, limites);

  function mudar(chave: ChaveAtributo, delta: number) {
    setErro(null);
    setValores((v) => {
      const novo = v[chave] + delta;
      if (novo < limites.minimo || novo > limites.maximo) return v;
      if (delta > 0 && restantes <= 0) return v;
      return { ...v, [chave]: novo };
    });
  }

  async function criar() {
    setEnviando(true);
    setErro(null);
    const r = await pedirAcao('/api/personagem/criar', valores);
    if (!r.ok) {
      setEnviando(false);
      setErro(r.erro);
      return;
    }
    toast.sucesso('Personagem criado', 'Agora é sobreviver.');
    router.replace('/personagem');
    router.refresh();
  }

  return (
    <Cartao variante="fita">
      <div className="space-y-1 text-center">
        <h1 className="font-titulo text-3xl tracking-wide">Quem é {nome}?</h1>
        <p className="text-sm text-texto-suave">
          Antes do fim, você era alguém. Agora é o que sobrou disso. Distribua {limites.total} pontos: cada atributo fica
          entre {limites.minimo} e {limites.maximo}.
        </p>
      </div>

      <div className="my-4 flex justify-center">
        <Selo tom={restantes === 0 ? 'verde' : 'ambar'}>
          {restantes === 0 ? 'Todos os pontos distribuídos' : `${restantes} ponto(s) restante(s)`}
        </Selo>
      </div>

      <ul className="space-y-2">
        {ATRIBUTOS.map((a) => {
          const v = valores[a.chave];
          const podeTirar = v > limites.minimo;
          const podeSomar = v < limites.maximo && restantes > 0;
          return (
            <li key={a.chave} className="flex items-center gap-3 rounded-md border border-borda bg-fundo-0/40 px-3 py-2">
              <IconeAtributo chave={a.chave} />
              <div className="min-w-0 flex-1">
                <p className="text-sm font-medium">{a.nome}</p>
                <p className="text-xs text-texto-suave">{a.usos}</p>
              </div>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => podeTirar && mudar(a.chave, -1)}
                  aria-disabled={!podeTirar || undefined}
                  aria-label={`Tirar 1 ponto de ${a.nome}`}
                  className={cn(BOTAO_PASSO, podeTirar ? 'border-borda hover:bg-fundo-2' : 'cursor-not-allowed border-borda opacity-40')}
                >
                  <Minus className="h-4 w-4" aria-hidden />
                </button>
                <span className="w-6 text-center font-mono text-xl" aria-live="polite" aria-label={`${a.nome}: ${v}`}>
                  {v}
                </span>
                <button
                  type="button"
                  onClick={() => podeSomar && mudar(a.chave, 1)}
                  aria-disabled={!podeSomar || undefined}
                  aria-label={`Somar 1 ponto em ${a.nome}`}
                  className={cn(
                    BOTAO_PASSO,
                    podeSomar
                      ? 'border-acento-verde bg-acento-verde/15 text-acento-verde hover:bg-acento-verde/30'
                      : 'cursor-not-allowed border-borda opacity-40',
                  )}
                >
                  <Plus className="h-4 w-4" aria-hidden />
                </button>
              </div>
            </li>
          );
        })}
      </ul>

      {erro && (
        <p role="alert" className="mt-4 rounded-md border border-acento-vermelho/60 bg-acento-vermelho/10 px-3 py-2 text-sm">
          {erro}
        </p>
      )}

      <div className="mt-5 flex flex-col gap-2 sm:flex-row sm:justify-between">
        <Botao variante="fantasma" onClick={() => setValores(inicial(limites.minimo))} motivoDesabilitado={restantes === limites.total - CHAVES_ATRIBUTOS.length * limites.minimo ? 'Nada para desfazer' : undefined}>
          Recomeçar
        </Botao>
        <Botao onClick={criar} carregando={enviando} motivoDesabilitado={problema ?? undefined}>
          Começar a sobreviver
        </Botao>
      </div>
    </Cartao>
  );
}
