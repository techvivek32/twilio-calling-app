import type { Metadata } from 'next';

import { HydrationMarker } from '@/components/hydration-marker';
import { ThemeSync, themeBootstrapScript } from '@/components/theme-toggle';
import './globals.css';

export const metadata: Metadata = {
  title: 'Vision Connect Admin',
  description:
    'Manage Twilio numbers, user assignments and call/SMS activity for Vision Connect.',
};

export default function RootLayout({ children }: LayoutProps<'/'>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        {/* Applies the saved theme before first paint. */}
        <script dangerouslySetInnerHTML={{ __html: themeBootstrapScript }} />
      </head>
      <body className="flex min-h-full flex-col">
        <ThemeSync />
        <HydrationMarker />
        {children}
      </body>
    </html>
  );
}
