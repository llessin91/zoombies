import {
  Backpack,
  Hammer,
  Home,
  Map as MapaIcone,
  Settings,
  Target,
  User,
  Users,
  Warehouse,
  type LucideIcon,
} from 'lucide-react';

export interface ItemNavegacao {
  href: string;
  rotulo: string;
  icone: LucideIcon;
}

// Ordem do menu lateral (desktop)
export const ITENS_NAVEGACAO: ItemNavegacao[] = [
  { href: '/inicio', rotulo: 'Início', icone: Home },
  { href: '/personagem', rotulo: 'Personagem', icone: User },
  { href: '/missoes', rotulo: 'Missões', icone: Target },
  { href: '/mapa', rotulo: 'Mapa', icone: MapaIcone },
  { href: '/abrigo', rotulo: 'Abrigo', icone: Warehouse },
  { href: '/recrutas', rotulo: 'Recrutas', icone: Users },
  { href: '/inventario', rotulo: 'Inventário', icone: Backpack },
  { href: '/fabricacao', rotulo: 'Fabricação', icone: Hammer },
  { href: '/ajustes', rotulo: 'Ajustes', icone: Settings },
];

// Barra inferior do celular: 5 ícones principais + botão "Mais"
const ORDEM_MOBILE = ['/inicio', '/missoes', '/abrigo', '/inventario', '/personagem'];

export const ITENS_MOBILE: ItemNavegacao[] = ORDEM_MOBILE.map(
  (href) => ITENS_NAVEGACAO.find((i) => i.href === href)!,
);

export const ITENS_MAIS: ItemNavegacao[] = ITENS_NAVEGACAO.filter(
  (i) => !ORDEM_MOBILE.includes(i.href),
);
