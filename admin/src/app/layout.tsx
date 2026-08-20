import type { Metadata } from 'next';

import { HydrationMarker } from '@/components/hydration-marker';
import './globals.css';

export const metadata: Metadata = {
  title: 'Business Connect Admin',
  description:
    'Manage Twilio numbers, user assignments and call/SMS activity for Business Connect.',
};

export default function RootLayout({ children }: LayoutProps<'/'>) {
  return (
    <html lang="en" className="h-full antialiased">
      <body className="flex min-h-full flex-col font-sans">
        <HydrationMarker />
        {children}
      </body>
    </html>
  );
}
