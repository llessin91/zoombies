import { cn } from '@/lib/utils';

export function Skeleton({ className }: { className?: string }) {
  return (
    <div
      aria-hidden
      className={cn(
        'animate-shimmer rounded-md bg-gradient-to-r from-fundo-2 via-borda/60 to-fundo-2 bg-[length:200%_100%]',
        className,
      )}
    />
  );
}

export function SkeletonCartao() {
  return (
    <div className="space-y-3 rounded-lg border border-borda bg-fundo-1 p-4">
      <Skeleton className="h-5 w-1/3" />
      <Skeleton className="h-3 w-full" />
      <Skeleton className="h-3 w-4/5" />
      <Skeleton className="h-9 w-28" />
    </div>
  );
}

export function SkeletonLista({ quantidade = 3 }: { quantidade?: number }) {
  return (
    <div role="status" className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
      <span className="sr-only">Carregando</span>
      {Array.from({ length: quantidade }).map((_, i) => (
        <SkeletonCartao key={i} />
      ))}
    </div>
  );
}
