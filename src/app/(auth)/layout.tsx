export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return (
    <main className="relative z-10 mx-auto flex min-h-dvh w-full max-w-md flex-col justify-center gap-6 px-4 py-10">
      <h1 className="text-center font-titulo text-4xl tracking-[0.25em] text-acento-verde">ZOMBIES</h1>
      {children}
    </main>
  );
}
