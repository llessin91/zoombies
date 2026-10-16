import type { Config } from 'tailwindcss';

// Cores vêm de variáveis CSS (canais RGB) para permitir alto contraste e opacidade (ex.: bg-acento-verde/20)
const cor = (nome: string) => `rgb(var(--${nome}) / <alpha-value>)`;

const config: Config = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        fundo: { 0: cor('fundo-0'), 1: cor('fundo-1'), 2: cor('fundo-2') },
        borda: cor('borda'),
        texto: { DEFAULT: cor('texto'), suave: cor('texto-suave') },
        acento: {
          verde: cor('acento-verde'),
          ambar: cor('acento-ambar'),
          vermelho: cor('acento-vermelho'),
          azul: cor('acento-azul'),
          roxo: cor('acento-roxo'),
          laranja: cor('acento-laranja'), // dificuldade "difícil"
        },
      },
      fontFamily: {
        titulo: ['var(--fonte-titulo)', 'Impact', 'sans-serif'],
        corpo: ['var(--fonte-corpo)', 'system-ui', 'sans-serif'],
        mono: ['var(--fonte-mono)', 'ui-monospace', 'monospace'],
      },
      keyframes: {
        pulsoSuave: {
          '0%, 100%': { boxShadow: '0 0 0 0 rgb(var(--acento-verde) / 0)' },
          '50%': { boxShadow: '0 0 18px 2px rgb(var(--acento-verde) / 0.35)' },
        },
        shimmer: {
          from: { backgroundPosition: '200% 0' },
          to: { backgroundPosition: '-200% 0' },
        },
        derivaLenta: {
          '0%': { transform: 'translateX(-14px)' },
          '100%': { transform: 'translateX(14px)' },
        },
        cambalear: {
          '0%, 100%': { transform: 'rotate(-3deg)' },
          '50%': { transform: 'rotate(3deg) translateY(-2px)' },
        },
      },
      animation: {
        'pulso-suave': 'pulsoSuave 2.4s ease-in-out infinite',
        shimmer: 'shimmer 2.2s linear infinite',
        'deriva-lenta': 'derivaLenta 9s ease-in-out infinite alternate',
        cambalear: 'cambalear 2.6s ease-in-out infinite',
      },
    },
  },
  plugins: [],
};

export default config;
