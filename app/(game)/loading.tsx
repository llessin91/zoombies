import { Skeleton, SkeletonLista } from '@/components/ui/Skeleton';

export default function Carregando() {
  return (
    <div className="space-y-6">
      <Skeleton className="h-9 w-56" />
      <SkeletonLista quantidade={3} />
    </div>
  );
}
