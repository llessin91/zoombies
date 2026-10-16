// src/components/game/IconeItem.tsx
// Ícone de cada item (recursos, consumíveis, armas, itens-chave). Na Fase 6 o inventário reaproveita.

import {
  Anvil, Bandage, Beef, Cable, Cog, Cpu, Crosshair, Droplets, Flame, FlaskConical, Fuel, GlassWater,
  Hammer, KeyRound, Package, Pill, Shirt, Siren, Sun, Swords, Syringe, TreePine, Wrench, type LucideIcon,
} from 'lucide-react';
import { cn } from '@/lib/utils';

const POR_SLUG: Record<string, LucideIcon> = {
  madeira: TreePine,
  sucata: Cog,
  metal: Anvil,
  tecido: Shirt,
  componentes_eletronicos: Cpu,
  combustivel: Fuel,
  pecas_mecanicas: Wrench,
  vidro: GlassWater,
  plastico: Package,
  fios_cabos: Cable,
  agua_potavel: Droplets,
  comida_enlatada: Beef,
  racao_militar: Beef,
  bandagem: Bandage,
  kit_primeiros_socorros: Syringe,
  antibiotico: Pill,
  antidoto: FlaskConical,
  analgesico: Pill,
  kit_reparo: Hammer,
  molotov: Flame,
  sinalizador: Siren,
  painel_solar: Sun,
};

const POR_TIPO: Record<string, LucideIcon> = {
  arma: Crosshair,
  item_chave: KeyRound,
  consumivel: Package,
  recurso: Package,
};

const CORPO_A_CORPO = new Set(['facao', 'machado', 'pe_de_cabra', 'bastao_de_beisebol', 'faca_de_caca']);

const COR_TIPO: Record<string, string> = {
  recurso: 'text-texto-suave',
  consumivel: 'text-acento-verde',
  arma: 'text-acento-laranja',
  item_chave: 'text-acento-ambar',
};

export function IconeItem({ slug, tipo, className }: { slug: string; tipo?: string; className?: string }) {
  const Icone = CORPO_A_CORPO.has(slug) ? Swords : POR_SLUG[slug] ?? POR_TIPO[tipo ?? ''] ?? Package;
  return <Icone aria-hidden className={cn('h-4 w-4 shrink-0', COR_TIPO[tipo ?? ''] ?? 'text-texto-suave', className)} />;
}
