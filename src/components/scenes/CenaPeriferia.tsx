// src/components/scenes/CenaPeriferia.tsx
// Periferia: casas baixas, postes com fios e lixo ao vento.

import { Camada, Zumbis, type PropsCena } from './BaseCena';

const CASAS = [
  [10, 70, 50], [90, 60, 40], [160, 80, 55], [255, 65, 45], [330, 90, 60], [435, 60, 42], [505, 85, 52], [605, 70, 46], [690, 95, 58],
];

export default function CenaPeriferia({ dificuldade, parada }: PropsCena) {
  return (
    <div aria-hidden className="absolute inset-0 overflow-hidden bg-gradient-to-b from-[#2a2f2a] via-[#1a1e1b] to-fundo-0">
      <div className="absolute right-[15%] top-[12%] h-14 w-14 rounded-full bg-[#d9c79a]/20 blur-md" />
      <Camada velocidade="lento" parada={parada} className="h-[70%] opacity-70">
        <g fill="#141815">
          {CASAS.map(([x, w, h]) => (
            <g key={x}>
              <rect x={x} y={200 - h} width={w} height={h} />
              <polygon points={`${x - 6},${200 - h} ${x + w / 2},${200 - h - 22} ${x + w + 6},${200 - h}`} />
            </g>
          ))}
        </g>
        <g fill="#c9b36a" opacity="0.35">
          <rect x="180" y="165" width="8" height="8" />
          <rect x="520" y="160" width="8" height="8" />
        </g>
      </Camada>
      <Camada velocidade="medio" parada={parada} className="h-[80%]">
        <g stroke="#0c0e0d" strokeWidth="4">
          {[60, 260, 460, 660].map((x) => (
            <g key={x}>
              <line x1={x} y1="200" x2={x} y2="60" />
              <line x1={x - 14} y1="70" x2={x + 14} y2="70" />
            </g>
          ))}
        </g>
        <g stroke="#0c0e0d" strokeWidth="1.2" fill="none">
          <path d="M60 72 Q160 100 260 72 Q360 100 460 72 Q560 100 660 72 Q730 95 800 72" />
          <path d="M0 74 Q30 92 60 74" />
        </g>
        <g fill="#0f1210">
          <rect x="0" y="182" width="800" height="18" />
          <ellipse cx="140" cy="182" rx="14" ry="9" />
          <ellipse cx="380" cy="183" rx="10" ry="7" />
          <rect x="560" y="168" width="40" height="14" />
        </g>
      </Camada>
      {/* Lixo ao vento */}
      <div className="absolute top-[58%] h-3 w-4 animate-vento rounded-sm bg-texto-suave/30" style={{ animationPlayState: parada ? 'paused' : 'running' }} />
      <div className="absolute top-[70%] h-2 w-3 animate-vento rounded-sm bg-texto-suave/20" style={{ animationDelay: '-7s', animationPlayState: parada ? 'paused' : 'running' }} />
      <Zumbis dificuldade={dificuldade} />
    </div>
  );
}
