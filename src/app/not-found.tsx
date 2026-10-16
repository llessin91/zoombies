import Link from 'next/link';

export default function NaoEncontrada() {
  return (
    <main className="relative z-10 flex min-h-dvh flex-col items-center justify-center gap-4 px-6 text-center">
      <h1 className="font-titulo text-5xl tracking-widest text-acento-vermelho">404</h1>
      <p className="max-w-sm text-texto-suave">Esta rua não existe. Ou os zumbis levaram.</p>
      <Link
        href="/inicio"
        className="inline-flex min-h-[44px] items-center rounded-md border border-acento-verde bg-acento-verde/20 px-4 text-sm font-medium hover:bg-acento-verde/30"
      >
        Voltar ao início
      </Link>
    </main>
  );
}
