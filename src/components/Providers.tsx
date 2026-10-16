'use client';

import { MotionConfig } from 'framer-motion';
import { ToastProvider } from '@/components/ui/Toast';

export function Providers({ children }: { children: React.ReactNode }) {
  // reducedMotion="user": Framer Motion obedece à preferência do sistema
  return (
    <MotionConfig reducedMotion="user">
      <ToastProvider>{children}</ToastProvider>
    </MotionConfig>
  );
}
