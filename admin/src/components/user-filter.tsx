'use client';

import { usePathname, useRouter, useSearchParams } from 'next/navigation';

/** Select that filters an activity table by user via the `user` query param. */
export function UserFilter({
  users,
}: {
  users: { id: string; name: string }[];
}) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const current = searchParams.get('user') ?? '';

  return (
    <label className="flex items-center gap-2 text-sm font-medium text-ink-soft">
      Filter
      <select
        className="field max-w-56 py-2"
        value={current}
        onChange={(event) => {
          const value = event.target.value;
          router.push(value ? `${pathname}?user=${value}` : pathname);
        }}
      >
        <option value="">All users</option>
        {users.map((user) => (
          <option key={user.id} value={user.id}>
            {user.name}
          </option>
        ))}
      </select>
    </label>
  );
}
