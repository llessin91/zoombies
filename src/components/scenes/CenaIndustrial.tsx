// src/components/scenes/CenaIndustrial.tsx
// Zona Industrial: chaminés com fumaça, guindastes e galpões.

import { Camada, Zumbis, type PropsCena } from './BaseCena';

export default function CenaIndustrial({ dificuldade, parada }: PropsCena) {
  const estado = { animationPlayState: parada ? 'paused' : 'running' } as const;
  return (
    <div aria-hidden className="absolute inset-0 overflow-hidden bg-gradient-to-b from-[#35291f] via-[#1d1814] to-fundo-0">
      {/* Fumaça das chaminés */}
      <div className="absolute left-[18%] top-[18%]">
        {[0, 2, 4].map((d) => (
          <span key={d} className="absolute h-8 w-8 animate-fumaca rounded-full bg-texto-suave/25" style={{ ...estado, animationDelay: `-${d}s` }} />
        ))}
      </div>
      <div className="absolute left-[64%] top-[24%]">
        {[1, 3, 5].map((d) => (
          <span key={d} className="absolute h-10 w-10 animate-fumaca rounded-full bg-texto-suave/20" style={{ ...estado, animationDelay: `-${d}s` }} />
        ))}
      </div>
      <Camada velocidade="lento" parada={parada} className="h-[85%] opacity-80">
        <g fill="#16110d">
          <rect x="140" y="40" width="22" height="160" />
          <rect x="510" y="60" width="26" height="140" />
          <rect x="0" y="130" width="230" height="70" />
          <polygon points="0,130 115,105 230,130" />
          <rect x="300" y="120" width="180" height="80" />
          <rect x="590" y="140" width="210" height="60" />
        </g>
        {/* Guindaste */}
        <g stroke="#120e0b" strokeWidth="5" fill="none">
          <line x1="420" y1="200" x2="420" y2="30" />
          <line x1="360" y1="34" x2="560" y2="34" />
          <line x1="420" y1="34" x2="380" y2="70" />
          <line x1="540" y1="34" x2="540" y2="80" strokeWidth="2" />
        </g>
        <rect x="528" y="80" width="24" height="16" fill="#120e0b" />
      </Camada>
      <Camada velocidade="medio" parada={parada} className="h-[40%]">
        <g fill="#0e0b09">
          <rect x="0" y="186" width="800" height="14" />
          <rect x="80" y="150" width="40" height="36" />
          <rect x="300" y="160" width="70" height="26" />
          <circle cx="560" cy="172" r="16" />
          <circle cx="600" cy="176" r="12" />
        </g>
      </Camada>
      <Zumbis dificuldade={dificuldade} />
    </div>
  );
}
