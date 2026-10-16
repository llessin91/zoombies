// src/lib/game/carregarEstado.ts
// Usado pelos layouts no servidor: sincroniza o personagem (catch-up) e devolve o estado.

import { criarClienteServidor } from '@/lib/supabase/server';
import { lerEstadoPersonagem, type EstadoPersonagem } from './personagem';

export type ResultadoCarga =
  | { tipo: 'sem_sessao' }
  | { tipo: 'sem_personagem' }
  | { tipo: 'erro'; faltaAtualizar: boolean }
  | { tipo: 'ok'; estado: EstadoPersonagem };

export async function carregarEstadoPersonagem(): Promise<ResultadoCarga> {
  const supabase = criarClienteServidor();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { tipo: 'sem_sessao' };

  const { data, error } = await supabase.rpc('sincronizar_estado');
  if (error) {
    console.error('[sincronizar_estado]', error.code, error.message);
    // PGRST202 / 42883 = função não existe: o SQL da Fase 3 ainda não foi rodado
    return { tipo: 'erro', faltaAtualizar: error.code === 'PGRST202' || error.code === '42883' };
  }

  try {
    const estado = lerEstadoPersonagem(data);
    return estado ? { tipo: 'ok', estado } : { tipo: 'sem_personagem' };
  } catch (e) {
    console.error('[estado_personagem formato]', e);
    return { tipo: 'erro', faltaAtualizar: true };
  }
}
