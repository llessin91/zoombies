// src/components/scenes/CenaCentro.tsx
// Centro Urbano: prédios altos, carros abandonados e letreiros piscando.

import { Camada, Zumbis, type PropsCena } from './BaseCena';

const PREDIOS = [
  [0, 70, 150], [75, 60, 175], [140, 90, 130], [235, 55, 190], [295, 80, 160], [380, 70, 185], [455, 95, 140], [555, 60, 170], [620, 85, 155], [710, 90, 180],
];

export default function CenaCentro({ dificuldade, parada }: PropsCena) {
  return (
    <div aria-hidden className="absolute inset-0 overflow-hidden bg-gradient-to-b from-[#1f2430] via-[#151820] to-fundo-0">
      <Camada velocidade="lento" parada={parada} className="h-[88%] opacity-80">
        <g fill="#10131a">
          {PREDIOS.map(([x, w, h]) => (
            <rect key={x} x={x} y={200 - h} width={w} height={h} />
          ))}
        </g>
        <g fill="#d7c27a" opacity="0.25">
          {PREDIOS.flatMap(([x, w, h]) =>
            [0, 1, 2, 3].map((i) => <rect key={`${x}-${i}`} x={x + 8 + (i % 2) * (w / 2)} y={200 - h + 14 + i * 26} width="7" height="9" />),
          )}
        </g>
        {/* Letreiros piscando */}
        <rect x="150" y="82" width="46" height="12" fill="#e74c3c" opacity="0.7" className="animate-piscar" />
        <rect x="470" y="70" width="58" height="12" fill="#3498db" opacity="0.7" className="animate-piscar" style={{ animationDelay: '-1.4s' }} />
      </Camada>
      <Camada velocidade="medio" parada={parada} className="h-[45%]">
        <g fill="#0b0d12">
          <rect x="0" y="185" width="800" height="15" />
          {[40, 230, 470, 640].map((x, i) => (
            <g key={x} transform={`rotate(${i % 2 ? -4 : 3} ${x + 40} 185)`}>
              <rect x={x} y="158" width="84" height="26" rx="6" />
              <rect x={x + 16} y="142" width="50" height="20" rx="6" />
              <circle cx={x + 18} cy="186" r="9" />
              <circle cx={x + 66} cy="186" r="9" />
            </g>
          ))}
        </g>
      </Camada>
      <Zumbis dificuldade={dificuldade} />
    </div>
  );
}
