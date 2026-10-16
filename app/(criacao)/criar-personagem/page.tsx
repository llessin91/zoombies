// src/app/(criacao)/criar-personagem/page.tsx
// Lê os limites da criação no game_config (12 pontos, mínimo 1, máximo 3) e mostra o formulário.

import type { Metadata } from 'next';
import { FormularioCriacao } from '@/components/game/FormularioCriacao';
import { montarConfig } from '@/lib/game/config';
import { criarClienteServidor } from '@/lib/supabase/server';

export const metadata: Metadata = { title: 'Criar personagem' };

export default async function Pagina() {
  const supabase = criarClienteServidor();
  const [{ data: linhas }, { data: auth }] = await Promise.all([
    supabase.from('game_config').select('chave, valor').like('chave', 'atributos.%'),
    supabase.auth.getUser(),
  ]);
  const { data: perfil } = auth.user
    ? await supabase.from('profiles').select('nome_sobrevivente').eq('id', auth.user.id).maybeSingle()
    : { data: null };

  const cfg = montarConfig(linhas);

  return (
    <FormularioCriacao
      nome={perfil?.nome_sobrevivente ?? 'Sobrevivente'}
      limites={{ total: cfg.atributos.pontosNaCriacao, minimo: cfg.atributos.minimoNaCriacao, maximo: cfg.atributos.maximoNaCriacao }}
    />
  );
}
