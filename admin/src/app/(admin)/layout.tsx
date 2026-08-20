import { redirect } from 'next/navigation';
import type { ReactNode } from 'react';

import { Sidebar } from '@/components/sidebar';
import { getSession } from '@/lib/auth';

export default async function AdminLayout({
  children,
}: {
  children: ReactNode;
}) {
  const session = await getSession();
  if (!session || session.role !== 'admin') redirect('/login');

  return (
    <div className="flex min-h-full flex-1 flex-col lg:flex-row">
      <Sidebar adminName={session.name} adminEmail={session.email} />
      <main className="min-w-0 flex-1 p-5 lg:p-8">{children}</main>
    </div>
  );
}
