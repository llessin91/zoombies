'use client';

// src/components/game/TelaAbrigo.tsx
// Tela do abrigo: escolha inicial (sem abrigo) ou planta com os espaços, status (depósito, energia,
// defesa, alertas), detalhe de cada instalação (coletar, melhorar, reparar, desmontar), catálogo para
// construir e reciclagem. Toda ação vai para o servidor; a tela só mostra o resultado.

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import {
  AlertTriangle,
  ArrowUpCircle,
  BatteryCharging,
  BedDouble,
  BrickWall,
  Construction,
  CookingPot,
  Cross,
  DoorClosed,
  Droplets,
  Dumbbell,
  Egg,
  FlaskConical,
  Fuel,
  Hammer,
  Home,
  LayoutGrid,
  MapPin,
  PackageOpen,
  Plus,
  Rabbit,
  Radio,
  Recycle,
  Shield,
  Siren,
  Sprout,
  Sun,
  Timer,
  TowerControl,
  Trash2,
  Warehouse,
  Wrench,
  Zap,
  ZapOff,
  type LucideIcon,
} from 'lucide-react';
import { Barra } from '@/components/ui/Barra';
import { Botao } from '@/components/ui/Botao';
import { Cartao } from '@/components/ui/Cartao';
import { EstadoVazio } from '@/components/ui/Estados';
import { Modal } from '@/components/ui/Modal';
import { Selo, type TomSelo } from '@/components/ui/Selo';
import { useToast } from '@/components/ui/Toast';
import { pedirAcao } from '@/lib/api/cliente';
import {
  ROTULO_AMEACA,
  ROTULO_CATEGORIA,
  ROTULO_DEFESA,
  ROTULO_ENERGIA,
  textoEfeitos,
  textoManutencao,
  textoProducao,
  type EstadoAbrigo,
  type EstadoAbrigoCom,
  type Instalacao,
  type ItemCatalogoAbrigo,
} from '@/lib/game/abrigo';
import { cn } from '@/lib/utils';
import { EscolhaAbrigo } from './EscolhaAbrigo';
import { useAgoraServidor, useEstadoJogo } from './EstadoJogo';
import { IconeItem } from './IconeItem';

const ICONE_INSTALACAO: Record<string, LucideIcon> = {
  residencia: BedDouble,
  area_treinamento: Dumbbell,
  oficina: Wrench,
  enfermaria: Cross,
  cozinha: CookingPot,
  muralha: BrickWall,
  torre_vigia: TowerControl,
  deposito: Warehouse,
  estacao_radio: Radio,
  saida_reforcada: DoorClosed,
  gerador_basico: Zap,
  gerador_avancado: BatteryCharging,
  painel_solar: Sun,
  horta: Sprout,
  captacao_agua: Droplets,
  galinheiro: Egg,
  armadilha_caca: Rabbit,
  oficina_reciclagem: Recycle,
  destilaria: FlaskConical,
};

const TOM_ENERGIA: Record<EstadoAbrigoCom['energia']['estado'], TomSelo> = {
  ok: 'verde',
  apertado: 'ambar',
  sem_energia: 'vermelho',
  sem_gerador: 'neutro',
};

const ROTULO_ESTADO: Record<Instalacao['estado'], string> = {
  construindo: 'Construindo',
  ativo: 'Ativa',
  danificado: 'Danificada',
  parado: 'Parada',
};

/** "1 h 05 min", "12 min", "40 s" */
export function formatarDuracao(ms: number): string {
  const s = Math.max(0, Math.ceil(ms / 1000));
  if (s < 60) return `${s} s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m} min`;
  const h = Math.floor(m / 60);
  return `${h} h ${String(m % 60).padStart(2, '0')} min`;
}

function tempoReal(dias: number, diasPorHora: number) {
  return formatarDuracao((dias / diasPorHora) * 3_600_000);
}

type Resposta = { estado: EstadoAbrigo };

export function TelaAbrigo({ inicial }: { inicial: EstadoAbrigo }) {
  const [estado, setEstado] = useState<EstadoAbrigo>(inicial);
  if (!estado.tem_abrigo) return <EscolhaAbrigo opcoes={estado.escolha} aoEscolher={setEstado} />;
  return <AbrigoAtivo estado={estado} setEstado={setEstado} />;
}

function AbrigoAtivo({ estado, setEstado }: { estado: EstadoAbrigoCom; setEstado: (e: EstadoAbrigo) => void }) {
  const toast = useToast();
  const reduzir = useReducedMotion();
  const { sincronizar } = useEstadoJogo();
  const agora = useAgoraServidor();
  const [aberta, setAberta] = useState<string | null>(null);
  const [construindoEm, setConstruindoEm] = useState<number | null | undefined>(undefined); // undefined = catálogo fechado
  const [desmontando, setDesmontando] = useState(false);
  const [enviando, setEnviando] = useState<string | null>(null);

  const { abrigo, deposito, energia, instalacoes, alertas } = estado;
  const instalacao = instalacoes.find((i) => i.id === aberta) ?? null;
  const prontas = instalacoes.reduce((s, i) => s + i.acumulada, 0);
  const temReciclagem = instalacoes.some((i) => i.slug === 'oficina_reciclagem' && i.estado === 'ativo');
  const conversoes = (estado.catalogo.find((c) => c.slug === 'oficina_reciclagem')?.producao.conversoes ?? {}) as Record<string, number>;

  const agir = useCallback(
    async (nome: string, caminho: string, corpo: unknown, sucesso: (e: EstadoAbrigoCom) => string | null) => {
      setEnviando(nome);
      const r = await pedirAcao<Resposta>(caminho, corpo);
      setEnviando(null);
      if (!r.ok) {
        toast.erro('Não deu certo', r.erro);
        return false;
      }
      setEstado(r.dados.estado);
      if (r.dados.estado.tem_abrigo) {
        const msg = sucesso(r.dados.estado);
        if (msg) toast.sucesso(msg);
      }
      void sincronizar(); // atributos, recursos no painel lateral
      return true;
    },
    [setEstado, sincronizar, toast],
  );

  // Quando alguma obra termina, pede o estado de novo ao servidor (ele decide se terminou)
  const proximaObra = useMemo(() => {
    const fins = instalacoes.filter((i) => i.estado === 'construindo' && i.concluido_em).map((i) => Date.parse(i.concluido_em!));
    return fins.length ? Math.min(...fins) : null;
  }, [instalacoes]);
  const pedindo = useRef(false);
  useEffect(() => {
    if (proximaObra === null || agora < proximaObra + 1000 || pedindo.current) return;
    pedindo.current = true;
    void pedirAcao<Resposta>('/api/abrigo/estado').then((r) => {
      pedindo.current = false;
      if (r.ok) {
        setEstado(r.dados.estado);
        void sincronizar();
      }
    });
  }, [agora, proximaObra, setEstado, sincronizar]);

  // Espaços da planta: instalações com slot + vazios
  const espacos = Array.from({ length: abrigo.slots }, (_, s) => instalacoes.find((i) => i.slot === s) ?? null);
  const semSlot = instalacoes.filter((i) => i.slot === null || i.slot >= abrigo.slots);

  return (
    <div className="space-y-4">
      {/* Cabeçalho do abrigo */}
      <Cartao variante="fita">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
          <div className="min-w-0 flex-1">
            <h2 className="font-titulo text-2xl tracking-wide">{abrigo.nome}</h2>
            <p className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-texto-suave">
              <span className="flex items-center gap-1">
                <MapPin className="h-3 w-3" aria-hidden /> {abrigo.local ?? '—'} · {abrigo.regiao_nome ?? '—'}
              </span>
              <span className="flex items-center gap-1">
                <LayoutGrid className="h-3 w-3" aria-hidden /> {instalacoes.length} / {abrigo.slots} espaços usados
              </span>
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            <Botao
              icone={<PackageOpen className="h-4 w-4" aria-hidden />}
              carregando={enviando === 'coletar-tudo'}
              motivoDesabilitado={prontas === 0 ? 'Nada pronto para coletar.' : undefined}
              onClick={() => agir('coletar-tudo', '/api/abrigo/coletar', {}, (e) => `Coletou ${e.coletado ?? 0} item(ns) para o depósito.`)}
            >
              Coletar tudo{prontas > 0 ? ` (${prontas})` : ''}
            </Botao>
            <Botao variante="secundario" icone={<Hammer className="h-4 w-4" aria-hidden />} onClick={() => setConstruindoEm(null)}>
              Construir
            </Botao>
            <Botao variante="fantasma" motivoDesabilitado="Mudar de abrigo chega na Fase 10.">
              Mudar de abrigo
            </Botao>
          </div>
        </div>
      </Cartao>

      {/* Alertas */}
      <AnimatePresence initial={false}>
        {alertas.length > 0 && (
          <motion.ul
            initial={reduzir ? false : { opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            className="space-y-1.5"
            aria-label="Alertas do abrigo"
          >
            {alertas.map((a) => (
              <li key={a.tipo} className="flex items-center gap-2 rounded-md border border-acento-ambar/50 bg-acento-ambar/10 px-3 py-2 text-sm">
                <AlertTriangle className="h-4 w-4 shrink-0 text-acento-ambar" aria-hidden />
                {a.texto}
              </li>
            ))}
          </motion.ul>
        )}
      </AnimatePresence>

      {/* Status */}
      <div className="grid gap-3 md:grid-cols-3">
        <Cartao>
          <div className="mb-1.5 flex items-center justify-between text-sm">
            <span className="flex items-center gap-2">
              <Warehouse className="h-4 w-4 text-texto-suave" aria-hidden /> Depósito
            </span>
            <span className="font-mono">
              {Math.round(deposito.usado)} / {Math.round(deposito.capacidade)}
            </span>
          </div>
          <Barra
            valor={deposito.usado}
            max={deposito.capacidade}
            tom={deposito.usado / Math.max(1, deposito.capacidade) >= 0.9 ? 'ambar' : 'azul'}
            rotulo="Uso do depósito"
            ocultarRotulo
          />
          <p className="mt-1.5 text-xs text-texto-suave">Cheio, a produção para. Loot e produção vêm para cá.</p>
        </Cartao>
        <Cartao>
          <div className="mb-1.5 flex items-center justify-between text-sm">
            <span className="flex items-center gap-2">
              {energia.estado === 'sem_energia' ? (
                <ZapOff className="h-4 w-4 text-acento-vermelho" aria-hidden />
              ) : (
                <Zap className={cn('h-4 w-4', energia.estado === 'sem_gerador' ? 'text-texto-suave' : 'text-acento-ambar', !reduzir && energia.estado === 'ok' && 'animate-pulse')} aria-hidden />
              )}
              Energia
            </span>
            <Selo tom={TOM_ENERGIA[energia.estado]}>{ROTULO_ENERGIA[energia.estado]}</Selo>
          </div>
          <p className="font-mono text-sm">
            {energia.oferta} oferta · {energia.demanda} demanda
          </p>
          <p className="mt-1 flex items-center gap-1.5 text-xs text-texto-suave">
            <Fuel className="h-3.5 w-3.5" aria-hidden />
            {energia.combustivel} combustível
            {energia.dias_combustivel !== null && ` · dura ~${Math.floor(energia.dias_combustivel)} dia(s) do jogo`}
          </p>
        </Cartao>
        <Cartao>
          <div className="flex items-center justify-between text-sm">
            <span className="flex items-center gap-2">
              <Shield className="h-4 w-4 text-texto-suave" aria-hidden /> Defesa
            </span>
            <Selo tom={estado.defesa === 'forte' ? 'verde' : estado.defesa === 'nenhuma' ? 'vermelho' : 'ambar'}>{ROTULO_DEFESA[estado.defesa]}</Selo>
          </div>
          <div className="mt-2 flex items-center justify-between text-sm">
            <span className="flex items-center gap-2">
              <Siren className="h-4 w-4 text-texto-suave" aria-hidden /> Ameaça na região
            </span>
            <Selo tom={estado.ameaca === 'alta' ? 'vermelho' : estado.ameaca === 'media' ? 'ambar' : 'verde'}>{ROTULO_AMEACA[estado.ameaca]}</Selo>
          </div>
          <p className="mt-1.5 text-xs text-texto-suave">Ataques ao abrigo chegam na Fase 10.</p>
        </Cartao>
      </div>

      {/* Planta */}
      <Cartao titulo="Planta do abrigo" subtitulo="Toque num espaço para ver a instalação ou construir.">
        <ul className="grid grid-cols-2 gap-2 sm:grid-cols-3 lg:grid-cols-4">
          {espacos.map((inst, s) => (
            <motion.li
              key={inst?.id ?? `vazio-${s}`}
              layout={!reduzir}
              initial={reduzir ? false : { opacity: 0, scale: 0.92 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ delay: s * 0.03 }}
            >
              {inst ? (
                <EspacoOcupado inst={inst} agora={agora} diasPorHora={estado.dias_jogo_por_hora_real} reduzir={Boolean(reduzir)} aoAbrir={() => setAberta(inst.id)} />
              ) : (
                <button
                  type="button"
                  onClick={() => setConstruindoEm(s)}
                  className="flex h-full min-h-[132px] w-full flex-col items-center justify-center gap-1 rounded-lg border border-dashed border-borda text-sm text-texto-suave transition-colors hover:border-acento-verde hover:text-texto focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde"
                >
                  <Plus className="h-5 w-5" aria-hidden />
                  Espaço {s + 1} livre
                </button>
              )}
            </motion.li>
          ))}
          {semSlot.map((inst) => (
            <li key={inst.id}>
              <EspacoOcupado inst={inst} agora={agora} diasPorHora={estado.dias_jogo_por_hora_real} reduzir={Boolean(reduzir)} aoAbrir={() => setAberta(inst.id)} />
            </li>
          ))}
        </ul>
      </Cartao>

      <div className="grid gap-3 lg:grid-cols-2">
        {/* Depósito */}
        <Cartao
          titulo="No depósito"
          acao={
            <Link href="/inventario" className="text-sm text-acento-verde underline-offset-2 hover:underline">
              Gerenciar
            </Link>
          }
        >
          {deposito.itens.length === 0 ? (
            <EstadoVazio compacto texto="Depósito vazio." detalhe="Loot de missões e produção vêm para cá." />
          ) : (
            <ul className="flex flex-wrap gap-1.5">
              {deposito.itens.map((i) => (
                <li key={i.id} className="flex items-center gap-1.5 rounded-md border border-borda bg-fundo-2 px-2 py-1 text-sm">
                  <IconeItem slug={i.slug} tipo={i.tipo} className="h-4 w-4" />
                  {i.nome}
                  <span className="font-mono text-xs text-texto-suave">×{i.quantidade}</span>
                </li>
              ))}
            </ul>
          )}
        </Cartao>

        {/* Reciclagem */}
        <Reciclagem
          ativa={temReciclagem}
          taxaMetal={Number(conversoes.sucata_para_metal ?? 3)}
          taxaComponentes={Number(conversoes.sucata_para_componentes ?? 5)}
          semEnergia={energia.estado === 'sem_energia'}
          sucata={deposito.itens.find((i) => i.slug === 'sucata')?.quantidade ?? 0}
          enviando={enviando}
          aoReciclar={(produto, vezes) =>
            agir(`reciclar-${produto}`, '/api/abrigo/reciclar', { produto, vezes }, () => `Reciclagem feita: ${vezes} ${produto === 'metal' ? 'metal' : 'componentes'}.`)
          }
        />
      </div>

      {/* Detalhe da instalação */}
      <Modal
        aberto={Boolean(instalacao)}
        aoFechar={() => {
          setAberta(null);
          setDesmontando(false);
        }}
        titulo={instalacao ? (instalacao.nome_nivel ?? instalacao.nome) : ''}
      >
        {instalacao && (
          <DetalheInstalacao
            inst={instalacao}
            agora={agora}
            diasPorHora={estado.dias_jogo_por_hora_real}
            enviando={enviando}
            desmontando={desmontando}
            setDesmontando={setDesmontando}
            aoColetar={() => agir('coletar', '/api/abrigo/coletar', { id: instalacao.id }, (e) => `Coletou ${e.coletado ?? 0} para o depósito.`)}
            aoMelhorar={() => agir('melhorar', '/api/abrigo/melhorar', { id: instalacao.id }, () => `Melhoria começou: ${instalacao.melhoria?.nome ?? instalacao.nome}.`)}
            aoReparar={() => agir('reparar', '/api/abrigo/reparar', { id: instalacao.id }, () => `Reparada: ${instalacao.nome}.`)}
            aoDesmontar={async () => {
              const ok = await agir('desmontar', '/api/abrigo/desmontar', { id: instalacao.id }, () => `Desmontada: ${instalacao.nome}. Parte do material voltou.`);
              if (ok) {
                setAberta(null);
                setDesmontando(false);
              }
            }}
          />
        )}
      </Modal>

      {/* Catálogo */}
      <Modal aberto={construindoEm !== undefined} aoFechar={() => setConstruindoEm(undefined)} titulo="Construir" largura="lg">
        <Catalogo
          catalogo={estado.catalogo}
          diasPorHora={estado.dias_jogo_por_hora_real}
          espaco={construindoEm ?? null}
          enviando={enviando}
          aoConstruir={async (c) => {
            const ok = await agir(`construir-${c.slug}`, '/api/abrigo/construir', { tipo: c.slug, slot: construindoEm ?? null }, () => `Obra começou: ${c.nome_nivel ?? c.nome}.`);
            if (ok) setConstruindoEm(undefined);
          }}
        />
      </Modal>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Um espaço ocupado na planta (com animações de obra, produção e falta de energia)
// ---------------------------------------------------------------------------
function EspacoOcupado({
  inst,
  agora,
  diasPorHora,
  reduzir,
  aoAbrir,
}: {
  inst: Instalacao;
  agora: number;
  diasPorHora: number;
  reduzir: boolean;
  aoAbrir: () => void;
}) {
  const Icone = ICONE_INSTALACAO[inst.slug] ?? Home;
  const obra = inst.estado === 'construindo' && inst.concluido_em;
  const fim = obra ? Date.parse(inst.concluido_em!) : 0;
  const total = (inst.tempo_dias / diasPorHora) * 3_600_000;
  const pctObra = obra && total > 0 ? Math.min(100, Math.max(0, 100 - ((fim - agora) / total) * 100)) : 0;
  const ciclo = Number(inst.producao.ciclo_dias ?? 0);
  const problema = inst.estado === 'parado' || inst.estado === 'danificado' || inst.sem_energia;

  return (
    <button
      type="button"
      onClick={aoAbrir}
      aria-label={`${inst.nome_nivel ?? inst.nome}: ${ROTULO_ESTADO[inst.estado]}${inst.acumulada > 0 ? `, ${inst.acumulada} pronto(s)` : ''}`}
      className={cn(
        'relative flex h-full min-h-[132px] w-full flex-col items-center gap-1.5 overflow-hidden rounded-lg border bg-fundo-1 p-3 text-center transition-transform hover:-translate-y-0.5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde',
        problema ? 'border-acento-vermelho/60' : obra ? 'border-acento-ambar/60' : 'border-borda',
      )}
    >
      {/* Faixas de obra */}
      {obra && (
        <span
          aria-hidden
          className={cn('pointer-events-none absolute inset-0 opacity-[0.08]', !reduzir && 'animate-[faixas_1.2s_linear_infinite]')}
          style={{
            backgroundImage: 'repeating-linear-gradient(45deg, rgb(var(--acento-ambar)) 0 10px, transparent 10px 20px)',
            backgroundSize: '28px 28px',
          }}
        />
      )}

      {/* Produção pronta */}
      <AnimatePresence>
        {inst.acumulada > 0 && (
          <motion.span
            key="pronto"
            initial={reduzir ? false : { scale: 0, y: 6 }}
            animate={reduzir ? { scale: 1 } : { scale: 1, y: [0, -3, 0] }}
            exit={{ scale: 0, opacity: 0 }}
            transition={reduzir ? undefined : { y: { repeat: Infinity, duration: 1.6 } }}
            className="absolute right-1.5 top-1.5 rounded-full bg-acento-verde px-2 text-xs font-semibold text-fundo-0"
          >
            +{inst.acumulada}
          </motion.span>
        )}
      </AnimatePresence>
      {inst.sem_energia && <ZapOff className="absolute left-1.5 top-1.5 h-4 w-4 text-acento-vermelho" aria-hidden />}

      <span className={cn('relative mt-2 flex h-11 w-11 items-center justify-center rounded-md bg-fundo-2', inst.sem_energia && 'opacity-50')}>
        {obra ? (
          <Construction className={cn('h-6 w-6 text-acento-ambar', !reduzir && 'animate-bounce')} aria-hidden />
        ) : (
          <Icone
            className={cn(
              'h-6 w-6',
              inst.categoria === 'energia' ? 'text-acento-ambar' : inst.categoria === 'producao' ? 'text-acento-verde' : 'text-acento-azul',
              !reduzir && inst.categoria === 'energia' && inst.estado === 'ativo' && !inst.sem_energia && 'animate-pulse',
            )}
            aria-hidden
          />
        )}
      </span>
      <span className="relative line-clamp-2 text-sm leading-tight">{inst.nome_nivel ?? inst.nome}</span>

      {obra ? (
        <span className="relative w-full space-y-1">
          <Barra valor={pctObra} max={100} tom="ambar" altura="sm" rotulo={`Obra de ${inst.nome}`} ocultarRotulo />
          <span className="flex items-center justify-center gap-1 font-mono text-xs text-texto-suave">
            <Timer className="h-3 w-3" aria-hidden /> {formatarDuracao(fim - agora)}
          </span>
        </span>
      ) : problema ? (
        <span className="relative text-xs text-acento-vermelho">{inst.sem_energia ? 'Sem energia' : ROTULO_ESTADO[inst.estado]}</span>
      ) : ciclo > 0 ? (
        <span className="relative w-full">
          <Barra valor={inst.progresso_dias} max={ciclo} tom="verde" altura="sm" rotulo={`Ciclo de produção de ${inst.nome}`} ocultarRotulo />
        </span>
      ) : (
        <span className="relative text-xs text-texto-suave">Nível {inst.nivel}</span>
      )}
    </button>
  );
}

// ---------------------------------------------------------------------------
// Detalhe de uma instalação
// ---------------------------------------------------------------------------
function DetalheInstalacao({
  inst,
  agora,
  diasPorHora,
  enviando,
  desmontando,
  setDesmontando,
  aoColetar,
  aoMelhorar,
  aoReparar,
  aoDesmontar,
}: {
  inst: Instalacao;
  agora: number;
  diasPorHora: number;
  enviando: string | null;
  desmontando: boolean;
  setDesmontando: (v: boolean) => void;
  aoColetar: () => void;
  aoMelhorar: () => void;
  aoReparar: () => void;
  aoDesmontar: () => void;
}) {
  const Icone = ICONE_INSTALACAO[inst.slug] ?? Home;
  const producao = textoProducao(inst.producao);
  const manutencao = textoManutencao(inst.manutencao);
  const efeitos = textoEfeitos(inst.efeitos);
  const ciclo = Number(inst.producao.ciclo_dias ?? 0);

  return (
    <div className="space-y-4">
      <div className="flex items-start gap-3">
        <span className="flex h-14 w-14 shrink-0 items-center justify-center rounded-lg border border-borda bg-fundo-2">
          <Icone className="h-7 w-7 text-acento-verde" aria-hidden />
        </span>
        <div className="space-y-1.5">
          <div className="flex flex-wrap gap-1.5">
            <Selo tom={inst.estado === 'ativo' ? 'verde' : inst.estado === 'construindo' ? 'ambar' : 'vermelho'}>{ROTULO_ESTADO[inst.estado]}</Selo>
            {inst.max_nivel > 1 && (
              <Selo>
                Nível {inst.nivel} de {inst.max_nivel}
              </Selo>
            )}
            {inst.consumo_energia > 0 && <Selo tom={inst.sem_energia ? 'vermelho' : 'ambar'} icone={<Zap className="h-3 w-3" aria-hidden />}>Usa {inst.consumo_energia} de energia</Selo>}
          </div>
          <p className="text-sm text-texto-suave">{inst.descricao}</p>
        </div>
      </div>

      {inst.estado === 'construindo' && inst.concluido_em && (
        <p className="flex items-center gap-2 rounded-md border border-acento-ambar/50 bg-acento-ambar/10 px-3 py-2 text-sm">
          <Timer className="h-4 w-4 text-acento-ambar" aria-hidden /> Fica pronta em {formatarDuracao(Date.parse(inst.concluido_em) - agora)}.
        </p>
      )}

      <ul className="space-y-1 text-sm">
        {producao && (
          <li className="flex items-start gap-2">
            <span aria-hidden className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-acento-verde" />
            Produz {producao}
            {ciclo > 0 && <span className="text-texto-suave"> (≈ {tempoReal(ciclo, diasPorHora)} reais por ciclo)</span>}
          </li>
        )}
        {manutencao && (
          <li className="flex items-start gap-2">
            <span aria-hidden className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-acento-ambar" />
            {manutencao}
          </li>
        )}
        {efeitos.map((e) => (
          <li key={e} className="flex items-start gap-2">
            <span aria-hidden className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-acento-azul" />
            {e}
          </li>
        ))}
      </ul>

      {inst.estado === 'parado' && <p className="text-sm text-acento-vermelho">Parada: faltou o item da manutenção no depósito. Ela volta sozinha quando houver estoque.</p>}
      {inst.sem_energia && <p className="text-sm text-acento-vermelho">Sem energia: precisa de gerador com combustível ou painel solar.</p>}

      {inst.item_produzido && (
        <div className="flex items-center justify-between rounded-md border border-borda px-3 py-2 text-sm">
          <span className="flex items-center gap-2">
            <IconeItem slug={inst.item_produzido} className="h-5 w-5" />
            Pronto para coletar: <strong className="font-mono">{inst.acumulada}</strong> {inst.item_produzido_nome}
          </span>
          <Botao variante="secundario" carregando={enviando === 'coletar'} motivoDesabilitado={inst.acumulada === 0 ? 'Nada pronto ainda.' : undefined} onClick={aoColetar}>
            Coletar
          </Botao>
        </div>
      )}

      {inst.melhoria && (
        <div className="space-y-2 rounded-md border border-borda px-3 py-2 text-sm">
          <p className="flex items-center gap-2 font-medium">
            <ArrowUpCircle className="h-4 w-4 text-acento-verde" aria-hidden /> Melhorar para {inst.melhoria.nome ?? `nível ${inst.nivel + 1}`}
          </p>
          <p className="text-texto-suave">Custo: {inst.melhoria.custo_texto}</p>
          <div className="flex justify-end">
            <Botao carregando={enviando === 'melhorar'} motivoDesabilitado={inst.melhoria.motivo ?? undefined} onClick={aoMelhorar}>
              Melhorar
            </Botao>
          </div>
        </div>
      )}

      {inst.estado === 'danificado' && inst.reparo_custo && (
        <div className="flex items-center justify-between rounded-md border border-acento-vermelho/50 px-3 py-2 text-sm">
          <span>Reparo: {inst.reparo_custo}</span>
          <Botao carregando={enviando === 'reparar'} onClick={aoReparar} icone={<Wrench className="h-4 w-4" aria-hidden />}>
            Reparar
          </Botao>
        </div>
      )}

      {!desmontando ? (
        <div className="flex justify-end">
          <Botao
            variante="perigo"
            icone={<Trash2 className="h-4 w-4" aria-hidden />}
            motivoDesabilitado={!inst.desmontavel ? 'Esta instalação não pode ser desmontada.' : inst.estado === 'construindo' ? 'Espere a obra terminar.' : undefined}
            onClick={() => setDesmontando(true)}
          >
            Desmontar
          </Botao>
        </div>
      ) : (
        <div className="space-y-3 rounded-md border border-acento-vermelho/50 bg-acento-vermelho/5 p-3 text-sm">
          <p>Desmontar devolve só metade do material do primeiro nível. O que estiver pronto para coletar se perde.</p>
          <div className="flex justify-end gap-2">
            <Botao variante="fantasma" onClick={() => setDesmontando(false)}>
              Cancelar
            </Botao>
            <Botao variante="perigo" carregando={enviando === 'desmontar'} onClick={aoDesmontar}>
              Desmontar
            </Botao>
          </div>
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Catálogo de construção
// ---------------------------------------------------------------------------
function Catalogo({
  catalogo,
  diasPorHora,
  espaco,
  enviando,
  aoConstruir,
}: {
  catalogo: ItemCatalogoAbrigo[];
  diasPorHora: number;
  espaco: number | null;
  enviando: string | null;
  aoConstruir: (c: ItemCatalogoAbrigo) => void;
}) {
  const [categoria, setCategoria] = useState<ItemCatalogoAbrigo['categoria']>('producao');
  const lista = catalogo.filter((c) => c.categoria === categoria);
  return (
    <div className="space-y-3">
      {espaco !== null && <p className="text-sm text-texto-suave">Construindo no espaço {espaco + 1}.</p>}
      <div role="tablist" aria-label="Categoria" className="flex flex-wrap gap-1.5">
        {(['producao', 'energia', 'estrutural'] as const).map((c) => (
          <button
            key={c}
            role="tab"
            type="button"
            aria-selected={categoria === c}
            onClick={() => setCategoria(c)}
            className={cn(
              'min-h-[40px] rounded-md border px-3 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde',
              categoria === c ? 'border-acento-verde bg-acento-verde/15' : 'border-borda hover:bg-fundo-2',
            )}
          >
            {ROTULO_CATEGORIA[c]}
          </button>
        ))}
      </div>
      <ul className="grid max-h-[60vh] gap-2 overflow-y-auto pr-1 sm:grid-cols-2">
        {lista.map((c) => {
          const Icone = ICONE_INSTALACAO[c.slug] ?? Home;
          const producao = textoProducao(c.producao);
          const efeitos = textoEfeitos(c.efeitos);
          return (
            <li key={c.slug} className={cn('flex flex-col gap-2 rounded-lg border bg-fundo-1 p-3', c.motivo ? 'border-borda' : 'border-acento-verde/50')}>
              <div className="flex items-start gap-2">
                <Icone className="mt-0.5 h-5 w-5 shrink-0 text-acento-verde" aria-hidden />
                <div className="min-w-0">
                  <p className="font-medium leading-tight">{c.nome_nivel ?? c.nome}</p>
                  <p className="text-xs text-texto-suave">{c.descricao}</p>
                </div>
              </div>
              <ul className="flex flex-wrap gap-1" aria-label="Custo">
                {c.custo_itens.map((ci) => {
                  const tem = ci.tem >= ci.qtd;
                  return (
                    <li
                      key={ci.item}
                      className={cn(
                        'flex items-center gap-1 rounded border px-1.5 py-0.5 text-xs',
                        tem ? 'border-acento-verde/50 text-acento-verde' : 'border-acento-vermelho/50 text-acento-vermelho',
                      )}
                    >
                      <IconeItem slug={ci.item} className="h-3.5 w-3.5" />
                      {ci.nome} {ci.tem}/{ci.qtd}
                    </li>
                  );
                })}
                {c.custo_itens.length === 0 && <li className="text-xs text-texto-suave">Sem custo</li>}
              </ul>
              <p className="text-xs text-texto-suave">
                <Timer className="mr-1 inline h-3 w-3" aria-hidden />
                {c.tempo_dias} dia(s) do jogo (≈ {tempoReal(c.tempo_dias, diasPorHora)} reais)
                {c.consumo_energia > 0 && ` · usa ${c.consumo_energia} de energia`}
              </p>
              {(producao || efeitos.length > 0) && (
                <p className="text-xs">{[producao && `Produz ${producao}`, ...efeitos].filter(Boolean).join(' · ')}</p>
              )}
              <div className="mt-auto flex justify-end">
                <Botao carregando={enviando === `construir-${c.slug}`} motivoDesabilitado={c.motivo ?? undefined} onClick={() => aoConstruir(c)}>
                  Construir
                </Botao>
              </div>
              {c.motivo && <p className="text-xs text-acento-vermelho">{c.motivo}</p>}
            </li>
          );
        })}
      </ul>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Oficina de reciclagem
// ---------------------------------------------------------------------------
function Reciclagem({
  ativa,
  taxaMetal,
  taxaComponentes,
  semEnergia,
  sucata,
  enviando,
  aoReciclar,
}: {
  ativa: boolean;
  taxaMetal: number;
  taxaComponentes: number;
  semEnergia: boolean;
  sucata: number;
  enviando: string | null;
  aoReciclar: (produto: 'metal' | 'componentes', vezes: number) => void;
}) {
  const [vezes, setVezes] = useState(1);
  const motivo = !ativa ? 'Construa a Oficina de reciclagem.' : semEnergia ? 'A oficina precisa de energia.' : undefined;
  return (
    <Cartao titulo="Reciclagem" subtitulo="Sucata vira material útil (na hora).">
      <div className="space-y-3 text-sm">
        <p className="flex items-center gap-2">
          <IconeItem slug="sucata" className="h-4 w-4" /> Sucata no depósito: <span className="font-mono">{sucata}</span>
        </p>
        <div className="flex items-center gap-2">
          <span className="text-texto-suave">Vezes:</span>
          <button
            type="button"
            aria-label="Menos 1"
            onClick={() => setVezes((v) => Math.max(1, v - 1))}
            className="h-9 w-9 rounded-md border border-borda hover:bg-fundo-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde"
          >
            −
          </button>
          <span className="w-8 text-center font-mono" aria-live="polite">
            {vezes}
          </span>
          <button
            type="button"
            aria-label="Mais 1"
            onClick={() => setVezes((v) => Math.min(50, v + 1))}
            className="h-9 w-9 rounded-md border border-borda hover:bg-fundo-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-acento-verde"
          >
            +
          </button>
        </div>
        <div className="flex flex-wrap gap-2">
          <Botao variante="secundario" carregando={enviando === 'reciclar-metal'} motivoDesabilitado={motivo} onClick={() => aoReciclar('metal', vezes)}>
            {taxaMetal * vezes} sucata → {vezes} metal
          </Botao>
          <Botao variante="secundario" carregando={enviando === 'reciclar-componentes'} motivoDesabilitado={motivo} onClick={() => aoReciclar('componentes', vezes)}>
            {taxaComponentes * vezes} sucata → {vezes} componentes
          </Botao>
        </div>
      </div>
    </Cartao>
  );
}
