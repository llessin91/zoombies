'use client';

// src/components/game/TelaExpedicao.tsx
// Execução da expedição: cena da região, barra contínua com marcador do evento, log com horário do jogo,
// evento (a barra pausa), "Pular" e resultado. Tudo é decidido no servidor; aqui só mostramos.
// Fechar a página não atrapalha: ao voltar, o servidor diz em que ponto está.

import { useCallback, useEffect, useRef, useState } from 'react';
import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import { BookOpen, FastForward, MapPin } from 'lucide-react';
import { CenaExpedicao } from '@/components/scenes/CenaExpedicao';
import { Barra } from '@/components/ui/Barra';
import { Botao } from '@/components/ui/Botao';
import { Modal } from '@/components/ui/Modal';
import { SeloDificuldade } from '@/components/ui/Selo';
import { useToast } from '@/components/ui/Toast';
import { pedirAcao } from '@/lib/api/cliente';
import { progressoExpedicao, type EstadoExpedicao } from '@/lib/game/expedicao';
import { relogioDoJogo } from '@/lib/game/tempo';
import { useEstadoJogo } from './EstadoJogo';
import { EventoModal } from './EventoModal';
import { ResultadoExpedicao } from './ResultadoExpedicao';

type Resposta = { expedicao: EstadoExpedicao };

export function TelaExpedicao({ inicial }: { inicial: EstadoExpedicao }) {
  const { estado: personagem, sincronizar } = useEstadoJogo();
  const toast = useToast();
  const [exp, setExp] = useState(inicial);
  const diferenca = useRef(Date.parse(inicial.servidor_agora) - Date.now());
  const [agora, setAgora] = useState(() => Date.parse(inicial.servidor_agora));
  const [escolhendo, setEscolhendo] = useState<number | null>(null);
  const [erroEvento, setErroEvento] = useState<string | null>(null);
  const [pulando, setPulando] = useState(false);
  const pedindo = useRef(false);
  const [diarioAberto, setDiarioAberto] = useState(false);
  const reduzir = useReducedMotion();

  const aplicar = useCallback((e: EstadoExpedicao) => {
    diferenca.current = Date.parse(e.servidor_agora) - Date.now();
    setExp(e);
  }, []);

  // Relógio da tela (4 vezes por segundo, para a barra andar macia)
  useEffect(() => {
    const id = window.setInterval(() => setAgora(Date.now() + diferenca.current), 250);
    return () => window.clearInterval(id);
  }, []);

  const iniciadaMs = Date.parse(exp.iniciada_em);
  const progresso =
    exp.estado === 'concluida'
      ? 1
      : progressoExpedicao({
          iniciadaMs,
          duracaoSeg: exp.duracao_seg,
          pausaSeg: exp.pausa_seg,
          agoraMs: agora,
          eventoEm: exp.evento_em,
          eventoResolvido: exp.evento_resolvido,
          aguardandoEvento: exp.estado === 'aguardando_evento',
        });

  // Pede ao servidor sem repetir pedidos em paralelo
  const pedir = useCallback(
    async (caminho: string, corpo?: unknown): Promise<string | null> => {
      if (pedindo.current) return null;
      pedindo.current = true;
      try {
        const r = await pedirAcao<Resposta>(caminho, corpo);
        if (!r.ok) return r.erro;
        aplicar(r.dados.expedicao);
        if (r.dados.expedicao.estado === 'concluida') void sincronizar(); // XP, nível, moral, stamina
        return null;
      } finally {
        pedindo.current = false;
      }
    },
    [aplicar, sincronizar],
  );

  // Chegou no evento ou no fim: confirma com o servidor
  const chegouNoEvento = exp.estado === 'em_andamento' && exp.evento_em !== null && !exp.evento_resolvido && progresso >= exp.evento_em;
  const chegouNoFim = exp.estado === 'em_andamento' && (exp.evento_em === null || exp.evento_resolvido) && agora >= Date.parse(exp.termina_em);
  useEffect(() => {
    if (!chegouNoEvento) return;
    void pedir(`/api/expedicao/${exp.id}/estado`);
    // Se o relógio do servidor ainda não bateu, pergunta de novo
    const id = window.setInterval(() => void pedir(`/api/expedicao/${exp.id}/estado`), 1500);
    return () => window.clearInterval(id);
  }, [chegouNoEvento, exp.id, pedir]);
  useEffect(() => {
    if (!chegouNoFim) return;
    let cancelado = false;
    // Se o relógio do servidor ainda não bateu, tenta de novo em 1 s
    const tentar = async () => {
      const erro = await pedir(`/api/expedicao/${exp.id}/finalizar`, { pular: false });
      if (erro && !cancelado) window.setTimeout(tentar, 1500);
    };
    void tentar();
    return () => {
      cancelado = true;
    };
  }, [chegouNoFim, exp.id, pedir]);

  async function escolher(indice: number) {
    setEscolhendo(indice);
    setErroEvento(null);
    pedindo.current = false;
    const erro = await pedir(`/api/expedicao/${exp.id}/evento`, { opcao: indice });
    setEscolhendo(null);
    if (erro) setErroEvento(erro);
  }

  async function pular() {
    setPulando(true);
    const erro = await pedir(`/api/expedicao/${exp.id}/finalizar`, { pular: true });
    setPulando(false);
    if (erro) toast.erro('Não deu para pular', erro);
  }

  async function confirmarLoot(escolha: Record<string, number>) {
    const erro = await pedir(`/api/expedicao/${exp.id}/loot`, { escolha });
    if (!erro) toast.sucesso('Mochila arrumada', 'O resto ficou para trás.');
    return erro;
  }

  // Linhas do log que já "aconteceram", com horário do jogo
  const momento = (pct: number) => {
    const pausa = exp.evento_em !== null && pct > exp.evento_em ? exp.pausa_seg : 0;
    const ms = iniciadaMs + (pct * exp.duracao_seg + pausa) * 1000;
    return relogioDoJogo(Date.parse(personagem.criado_em), ms, personagem.dias_jogo_por_hora_real, personagem.hora_inicial);
  };
  const linhas = exp.log
    .filter((l) => (l.fim ? exp.estado === 'concluida' : l.pct <= progresso + 0.0001))
    .sort((a, b) => a.pct - b.pct || Number(Boolean(a.evento)) - Number(Boolean(b.evento)));

  // Legenda: só o acontecimento mais recente aparece; o anterior some quando o novo chega
  const atual = linhas[linhas.length - 1];
  const indiceAtual = linhas.length - 1;
  const hora = (pct: number) => {
    const r = momento(pct);
    return `${String(r.hora).padStart(2, '0')}:${String(r.minuto).padStart(2, '0')}`;
  };

  const parada = exp.estado !== 'em_andamento';
  const segundosRestantes = Math.max(0, Math.ceil((Date.parse(exp.termina_em) - agora) / 1000));

  return (
    <div className="space-y-4">
      {/* Cena + barra */}
      <section aria-label="Expedição" className="overflow-hidden rounded-lg border border-borda bg-fundo-1">
        <div className="relative h-52 sm:h-64 lg:h-72">
          <CenaExpedicao regiao={exp.missao.regiao} dificuldade={exp.missao.dificuldade} parada={parada} />
          <div className="absolute left-3 right-3 top-3 flex flex-wrap items-center gap-2">
            <span className="rounded bg-fundo-0/70 px-2 py-0.5 font-titulo text-sm tracking-wide">{exp.missao.nome}</span>
            <SeloDificuldade nivel={exp.missao.dificuldade} />
            <span className="flex items-center gap-1 rounded bg-fundo-0/70 px-2 py-0.5 text-xs">
              <MapPin className="h-3 w-3" aria-hidden />
              {exp.missao.local}
              {exp.missao.ponto && ` · ${exp.missao.ponto}`}
            </span>
          </div>

          {/* Legenda do acontecimento atual, sobre a cena */}
          <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-black/85 via-black/60 to-transparent px-4 pb-3 pt-10">
            <div className="relative min-h-[3.5rem] overflow-hidden" aria-live="polite" aria-atomic="true">
              <AnimatePresence initial={false} mode="popLayout">
                {atual && (
                  <motion.p
                    key={indiceAtual}
                    initial={reduzir ? false : { opacity: 0, y: 14 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={reduzir ? { opacity: 0, transition: { duration: 0 } } : { opacity: 0, y: -14 }}
                    transition={{ duration: reduzir ? 0 : 0.5, ease: 'easeOut' }}
                    className={
                      atual.evento
                        ? 'border-l-2 border-acento-ambar pl-2 text-sm text-acento-ambar sm:text-base'
                        : atual.fim
                          ? 'border-l-2 border-acento-verde pl-2 text-sm font-medium text-texto sm:text-base'
                          : 'text-sm text-texto sm:text-base'
                    }
                  >
                    <span className="mr-2 font-mono text-xs text-texto-suave">{hora(atual.pct)}</span>
                    {atual.texto}
                  </motion.p>
                )}
              </AnimatePresence>
            </div>
          </div>
        </div>
        <div className="space-y-2 p-3">
          <Barra
            valor={Math.round(progresso * 1000)}
            max={1000}
            tom={exp.estado === 'concluida' ? 'verde' : 'ambar'}
            rotulo="Progresso da expedição"
            ocultarRotulo
            marcador={exp.evento_em !== null && !exp.evento_resolvido ? exp.evento_em : undefined}
            altura="md"
          />
          <div className="flex flex-wrap items-center justify-between gap-2 text-xs text-texto-suave">
            <span aria-live="polite">
              {exp.estado === 'concluida'
                ? 'Expedição concluída'
                : exp.estado === 'aguardando_evento'
                  ? 'Parado: uma decisão espera por você'
                  : `${Math.round(progresso * 100)}% · ${segundosRestantes > 0 ? `${segundosRestantes} s restantes` : 'chegando'}`}
            </span>
            {exp.estado === 'concluida' && (
              <Botao variante="fantasma" onClick={() => setDiarioAberto(true)} icone={<BookOpen className="h-4 w-4" aria-hidden />}>
                Ver diário completo
              </Botao>
            )}
            {exp.estado === 'em_andamento' && (
              <Botao variante="fantasma" onClick={pular} carregando={pulando} icone={<FastForward className="h-4 w-4" aria-hidden />}>
                Pular
              </Botao>
            )}
          </div>
        </div>
      </section>

      {exp.estado === 'concluida' && exp.resultado && <ResultadoExpedicao expedicao={exp} aoConfirmarLoot={confirmarLoot} />}

      {/* Diário completo: só depois que a expedição termina */}
      <Modal aberto={diarioAberto} aoFechar={() => setDiarioAberto(false)} titulo="Diário da expedição" largura="lg">
        <ol className="space-y-2">
          {linhas.map((l, i) => (
            <li key={`${l.pct}-${i}`} className={l.evento ? 'border-l-2 border-acento-ambar/70 pl-2' : l.fim ? 'border-l-2 border-acento-verde/70 pl-2' : ''}>
              <span className="mr-2 font-mono text-xs text-texto-suave">{hora(l.pct)}</span>
              <span className="text-sm">{l.texto}</span>
            </li>
          ))}
        </ol>
      </Modal>

      <EventoModal evento={exp.estado === 'aguardando_evento' ? exp.evento : null} enviando={escolhendo} erro={erroEvento} aoEscolher={escolher} />
    </div>
  );
}
