import { cn } from '@/lib/utils';

// Prédios em ruínas: x, largura, altura (topo quebrado em diagonal)
const FUNDO = [
  [0, 90, 150], [80, 70, 210], [140, 100, 120], [230, 80, 240], [300, 110, 160], [405, 70, 200],
  [470, 120, 130], [585, 80, 230], [660, 100, 170], [755, 70, 250], [820, 110, 140], [925, 90, 200],
  [1010, 100, 160], [1100, 100, 220],
];
const FRENTE = [
  [20, 110, 90], [150, 90, 130], [260, 120, 80], [400, 100, 120], [530, 130, 90], [690, 90, 140],
  [800, 120, 100], [940, 100, 130], [1060, 140, 95],
];

function predios(lista: number[][], base: number) {
  return lista.map(([x, w, h]) => (
    <polygon
      key={`${x}-${w}`}
      points={`${x},${base} ${x},${base - h} ${x + w * 0.55},${base - h} ${x + w},${base - h + 22} ${x + w},${base}`}
    />
  ));
}

function Zumbi({ className, atraso }: { className?: string; atraso: string }) {
  return (
    <div className={cn('absolute animate-deriva-lenta', className)} style={{ animationDelay: atraso }}>
      <svg viewBox="0 0 60 100" className="h-20 w-12 origin-bottom animate-cambalear fill-black/70" style={{ animationDelay: atraso }}>
        <circle cx="20" cy="12" r="8" />
        <rect x="12" y="20" width="16" height="38" rx="4" />
        <rect x="26" y="26" width="28" height="6" rx="3" />
        <rect x="26" y="37" width="24" height="6" rx="3" />
        <rect x="13" y="58" width="8" height="38" rx="3" />
        <rect x="25" y="58" width="8" height="38" rx="3" transform="rotate(10 29 58)" />
      </svg>
    </div>
  );
}

// Cena de fundo de login e cadastro: cidade em ruínas com zumbis distantes
export function CenaRuinas() {
  return (
    <div aria-hidden className="pointer-events-none fixed inset-0 z-0 overflow-hidden">
      <div className="absolute inset-0 bg-gradient-to-b from-fundo-2 via-fundo-1 to-fundo-0" />
      <div className="absolute left-[12%] top-[10%] h-24 w-24 rounded-full bg-texto/10 blur-2xl" />
      <svg viewBox="0 0 1200 300" preserveAspectRatio="xMidYMax slice" className="absolute bottom-0 h-[62%] w-full">
        <g className="fill-fundo-2">{predios(FUNDO, 300)}</g>
        <g className="fill-fundo-1">{predios(FRENTE, 300)}</g>
      </svg>
      <div className="absolute inset-x-0 bottom-[6%] h-24">
        <Zumbi className="bottom-0 left-[8%]" atraso="0s" />
        <Zumbi className="bottom-0 left-[34%] scale-75" atraso="-1.2s" />
        <Zumbi className="bottom-0 left-[62%]" atraso="-0.6s" />
        <Zumbi className="bottom-0 left-[84%] scale-90" atraso="-1.8s" />
      </div>
    </div>
  );
}
