// src/app/(game)/personagem/page.tsx
import type { Metadata } from 'next';
import { PaginaBase } from '@/components/game/PaginaBase';
import { TelaPersonagem } from '@/components/game/TelaPersonagem';

export const metadata: Metadata = { title: 'Personagem' };

export default function Pagina() {
  return (
    <PaginaBase titulo="Personagem" descricao="Quem você é depois do fim do mundo. Atributos só sobem com pontos de nível.">
      <TelaPersonagem />
    </PaginaBase>
  );
}
