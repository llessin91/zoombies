// src/components/scenes/CenaMilitar.tsx
// Zona Militar e Científica: cercas, holofotes, bunkers e laboratórios com luz fria.

import { Camada, Zumbis, type PropsCena } from './BaseCena';

export default function CenaMilitar({ dificuldade, parada }: PropsCena) {
  const estado = { animationPlayState: parada ? 'paused' : 'running' } as const;
  return (
    <div aria-hidden className="absolute inset-0 overflow-hidden bg-gradient-to-b from-[#18222a] via-[#10161b] to-fundo-0">
      {/* Holofotes varrendo */}
      <div className="absolute bottom-[30%] left-[22%] h-[70%] w-16 origin-bottom animate-holofote" style={estado}>
        <div className="h-full w-full bg-gradient-to-t from-[#bfe6ff]/25 to-transparent [clip-path:polygon(40%_100%,60%_100%,100%_0,0_0)]" />
      </div>
      <div className="absolute bottom-[30%] left-[72%] h-[65%] w-14 origin-bottom animate-holofote" style={{ ...estado, animationDelay: '-3s' }}>
        <div className="h-full w-full bg-gradient-to-t from-[#bfe6ff]/20 to-transparent [clip-path:polygon(40%_100%,60%_100%,100%_0,0_0)]" />
      </div>
      <Camada velocidade="lento" parada={parada} className="h-[75%] opacity-85">
        <g fill="#0b1014">
          {/* Laboratório */}
          <rect x="420" y="90" width="220" height="110" />
          <rect x="120" y="120" width="110" height="80" />
          {/* Bunkers */}
          <path d="M0 200 Q60 140 120 200 Z" />
          <path d="M680 200 Q740 150 800 200 Z" />
          <rect x="230" y="60" width="10" height="140" />
          <rect x="216" y="56" width="38" height="12" />
        </g>
        <g fill="#9fd8ff" opacity="0.35">
          {[0, 1, 2, 3, 4].map((i) => (
            <rect key={i} x={436 + i * 40} y="110" width="22" height="10" />
          ))}
          {[0, 1, 2, 3, 4].map((i) => (
            <rect key={`b${i}`} x={436 + i * 40} y="140" width="22" height="10" className={i === 2 ? 'animate-piscar' : undefined} />
          ))}
        </g>
      </Camada>
      <Camada velocidade="medio" parada={parada} className="h-[35%]">
        {/* Cerca */}
        <g stroke="#080b0e" strokeWidth="2">
          {Array.from({ length: 21 }, (_, i) => (
            <line key={i} x1={i * 40} y1="200" x2={i * 40} y2="120" strokeWidth="5" />
          ))}
          <line x1="0" y1="124" x2="800" y2="124" />
          <line x1="0" y1="150" x2="800" y2="150" />
          <line x1="0" y1="176" x2="800" y2="176" />
        </g>
        <g stroke="#080b0e" strokeWidth="1" opacity="0.8">
          {Array.from({ length: 40 }, (_, i) => (
            <line key={i} x1={i * 20} y1="200" x2={i * 20 + 20} y2="124" />
          ))}
        </g>
      </Camada>
      <Zumbis dificuldade={dificuldade} />
    </div>
  );
}
