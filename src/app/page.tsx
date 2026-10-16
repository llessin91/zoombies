import { redirect } from 'next/navigation';

// Na Fase 2 isto passa a decidir entre /login e /inicio conforme a sessão
export default function Raiz() {
  redirect('/inicio');
}
