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
        // Faixas de obra andando (abrigo)
        faixas: { from: { backgroundPosition: '0 0' }, to: { backgroundPosition: '28px 0' } },
        pulsoSuave: {
          '0%, 100%': { boxShadow: '0 0 0 0 rgb(var(--acento-verde) / 0)' },
          '50%': { boxShadow: '0 0 18px 2px rgb(var(--acento-verde) / 0.35)' },
        },
        shimmer: {
          from: { backgroundPosition: '200% 0' },
          to: { backgroundPosition: '-200% 0' },
        },
        parallax: { from: { transform: 'translateX(0)' }, to: { transform: 'translateX(-50%)' } },
        piscar: {
          '0%, 40%, 100%': { opacity: '1' },
          '45%': { opacity: '0.15' },
          '50%': { opacity: '0.9' },
          '55%': { opacity: '0.3' },
        },
        fumaca: {
          '0%': { transform: 'translateY(0) scale(0.6)', opacity: '0.55' },
          '100%': { transform: 'translateY(-70px) scale(1.8)', opacity: '0' },
        },
        holofote: { '0%': { transform: 'rotate(-28deg)' }, '100%': { transform: 'rotate(28deg)' } },
        vento: {
          '0%': { transform: 'translateX(-5vw) rotate(0deg)' },
          '100%': { transform: 'translateX(110vw) rotate(720deg)' },
        },
        explodir: {
          '0%': { transform: 'scale(0.6)', opacity: '0' },
          '60%': { transform: 'scale(1.08)', opacity: '1' },
          '100%': { transform: 'scale(1)', opacity: '1' },
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
        'parallax-lento': 'parallax 90s linear infinite',
        'parallax-medio': 'parallax 40s linear infinite',
        piscar: 'piscar 3.2s steps(1, end) infinite',
        fumaca: 'fumaca 6s ease-out infinite',
        holofote: 'holofote 6s ease-in-out infinite alternate',
        vento: 'vento 16s linear infinite',
        explodir: 'explodir 0.6s ease-out both',
      },
    },
  },
  plugins: [],
};

export default config;
