import type { Metadata, Viewport } from 'next';
import { Inter, JetBrains_Mono, Staatliches } from 'next/font/google';
import { Providers } from '@/components/Providers';
import '@/styles/globals.css';

const titulo = Staatliches({ subsets: ['latin'], weight: '400', variable: '--fonte-titulo', display: 'swap' });
const corpo = Inter({ subsets: ['latin'], variable: '--fonte-corpo', display: 'swap' });
const mono = JetBrains_Mono({ subsets: ['latin'], variable: '--fonte-mono', display: 'swap' });

export const metadata: Metadata = {
  title: { default: 'Zombies', template: '%s · Zombies' },
  description: 'Um jogo pra provar que você conseguiria sobreviver a um mundo apocalíptico zumbi.',
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  themeColor: '#0b0d0c',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR" className={`${titulo.variable} ${corpo.variable} ${mono.variable}`}>
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
