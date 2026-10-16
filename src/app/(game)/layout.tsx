import { ShellJogo } from '@/components/game/ShellJogo';

// Fase 2 adicionará aqui a proteção de rotas (exigir login)
export default function GameLayout({ children }: { children: React.ReactNode }) {
  return <ShellJogo>{children}</ShellJogo>;
}
