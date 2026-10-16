'use client';

import { useState } from 'react';
import { Archive, Skull } from 'lucide-react';
import { PaginaBase } from '@/components/game/PaginaBase';
import { Abas } from '@/components/ui/Abas';
import { Barra } from '@/components/ui/Barra';
import { Botao } from '@/components/ui/Botao';
import { Cartao } from '@/components/ui/Cartao';
import { EstadoErro, EstadoVazio } from '@/components/ui/Estados';
import { Modal } from '@/components/ui/Modal';
import { Selo, SeloDificuldade, SeloRaridade } from '@/components/ui/Selo';
import { Skeleton, SkeletonLista } from '@/components/ui/Skeleton';
import { Tooltip } from '@/components/ui/Tooltip';
import { useToast } from '@/components/ui/Toast';

// Página temporária só para testar os componentes (removida na Fase 12)
export default function KitUiPage() {
  const toast = useToast();
  const [carregando, setCarregando] = useState(false);
  const [modal, setModal] = useState(false);
  const [modalCritico, setModalCritico] = useState(false);
  const [aba, setAba] = useState('a');
  const [moral, setMoral] = useState(70);

  function simularCarga() {
    setCarregando(true);
    setTimeout(() => setCarregando(false), 2000);
  }

  return (
    <PaginaBase titulo="Kit de componentes" descricao="Página de teste da Fase 1. Será removida na Fase 12.">
      <div className="grid gap-6 lg:grid-cols-2">
        <Cartao titulo="Botões" variante="fita">
          <div className="flex flex-wrap items-center gap-3">
            <Botao>Primário</Botao>
            <Botao variante="secundario">Secundário</Botao>
            <Botao variante="perigo">Perigo</Botao>
            <Botao variante="fantasma">Fantasma</Botao>
          </div>
          <div className="mt-4 flex flex-wrap items-center gap-3">
            <Botao motivoDesabilitado="Stamina insuficiente">Desabilitado (passe o mouse)</Botao>
            <Botao carregando={carregando} onClick={simularCarga}>
              Carregar 2s
            </Botao>
          </div>
          <div className="mt-4 flex flex-wrap items-center gap-3">
            <Botao variante="acao" custoStamina={3}>
              Iniciar expedição
            </Botao>
            <Botao variante="acao" custoStamina={5} motivoDesabilitado="Stamina insuficiente">
              Iniciar expedição
            </Botao>
          </div>
        </Cartao>

        <Cartao titulo="Selos" indice={1}>
          <div className="flex flex-wrap gap-2">
            <SeloDificuldade nivel="facil" />
            <SeloDificuldade nivel="media" />
            <SeloDificuldade nivel="dificil" />
            <SeloDificuldade nivel="lendaria" />
          </div>
          <div className="mt-3 flex flex-wrap gap-2">
            <SeloRaridade nivel="comum" />
            <SeloRaridade nivel="incomum" />
            <SeloRaridade nivel="raro" />
            <SeloRaridade nivel="epico" />
            <SeloRaridade nivel="lendario" />
          </div>
          <div className="mt-3 flex flex-wrap items-center gap-2">
            <Selo tom="vermelho" icone={<Skull className="h-3 w-3" aria-hidden />}>
              Risco
            </Selo>
            <Tooltip conteudo="Exemplo de dica">
              <Selo tom="azul">Passe o mouse aqui</Selo>
            </Tooltip>
          </div>
        </Cartao>

        <Cartao titulo="Barras" indice={2}>
          <div className="space-y-4">
            <Barra rotulo="XP" valor={40} max={100} tom="roxo" mostrarValor />
            <Barra rotulo="Stamina" valor={14} max={20} tom="ambar" brilho mostrarValor />
            <Barra rotulo="Moral (mude no controle)" valor={moral} max={100} tom="moral" mostrarValor />
            <input
              type="range"
              min={0}
              max={100}
              value={moral}
              onChange={(e) => setMoral(Number(e.target.value))}
              aria-label="Ajustar moral de teste"
              className="w-full accent-[rgb(var(--acento-verde))]"
            />
            <Barra rotulo="Progresso com marcador de evento" valor={35} max={100} tom="verde" marcador={0.6} altura="lg" />
          </div>
        </Cartao>

        <Cartao titulo="Modais, toasts e abas" indice={3}>
          <div className="flex flex-wrap gap-3">
            <Botao variante="secundario" onClick={() => setModal(true)}>
              Abrir modal
            </Botao>
            <Botao variante="perigo" onClick={() => setModalCritico(true)}>
              Modal crítico
            </Botao>
          </div>
          <div className="mt-3 flex flex-wrap gap-2">
            <Botao variante="fantasma" onClick={() => toast.sucesso('Pronto', 'Tudo certo.')}>Toast sucesso</Botao>
            <Botao variante="fantasma" onClick={() => toast.erro('Falhou', 'Algo deu errado.')}>Toast erro</Botao>
            <Botao variante="fantasma" onClick={() => toast.aviso('Atenção', 'Estoque baixo.')}>Toast aviso</Botao>
            <Botao variante="fantasma" onClick={() => toast.info('Dica', 'Ande em silêncio.')}>Toast info</Botao>
          </div>
          <div className="mt-4">
            <Abas
              rotuloLista="Exemplo de abas"
              abas={[
                { id: 'a', rotulo: 'Fabricar' },
                { id: 'b', rotulo: 'Reparar' },
                { id: 'c', rotulo: 'Em andamento', indicador: true },
              ]}
              valor={aba}
              aoMudar={setAba}
            >
              <p className="text-sm text-texto-suave">Conteúdo da aba {aba.toUpperCase()}. Use as setas do teclado para trocar.</p>
            </Abas>
          </div>
        </Cartao>

        <Cartao titulo="Skeleton" indice={4}>
          <Skeleton className="mb-3 h-6 w-40" />
          <SkeletonLista quantidade={2} />
        </Cartao>

        <Cartao titulo="Estados vazio e erro" indice={5}>
          <EstadoVazio icone={<Archive className="h-8 w-8" aria-hidden />} texto="Nada aqui. Nem os zumbis passaram." />
          <EstadoErro mensagem="Não deu para carregar." aoTentarNovamente={() => toast.info('Tentando de novo…')} />
        </Cartao>
      </div>

      <Modal aberto={modal} aoFechar={() => setModal(false)} titulo="Modal de exemplo">
        <p className="text-sm text-texto-suave">Feche com ESC, com o X ou clicando fora. O foco fica preso aqui dentro.</p>
        <div className="mt-4 flex justify-end">
          <Botao onClick={() => setModal(false)}>Entendi</Botao>
        </div>
      </Modal>

      <Modal aberto={modalCritico} aoFechar={() => setModalCritico(false)} titulo="Modal crítico" critico>
        <p className="text-sm text-texto-suave">Este modal NÃO fecha com ESC nem clicando fora. Só pelos botões.</p>
        <div className="mt-4 flex justify-end gap-2">
          <Botao variante="secundario" onClick={() => setModalCritico(false)}>Cancelar</Botao>
          <Botao variante="perigo" onClick={() => setModalCritico(false)}>Confirmar</Botao>
        </div>
      </Modal>
    </PaginaBase>
  );
}
