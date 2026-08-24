'use client';

import Image from 'next/image';
import { useActionState } from 'react';
import { useFormStatus } from 'react-dom';

import { IconAlert } from '@/components/icons';
import { ThemeToggle } from '@/components/theme-toggle';

import { loginAction, type LoginState } from './actions';

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <button type="submit" className="btn-primary w-full py-3" disabled={pending}>
      {pending ? 'Signing in…' : 'Sign in'}
    </button>
  );
}

export default function LoginPage() {
  const [state, formAction] = useActionState<LoginState, FormData>(
    loginAction,
    {},
  );

  return (
    <main className="flex flex-1 flex-col items-center justify-center px-5 py-10">
      <div className="w-full max-w-sm">
        <div className="mb-7 flex flex-col items-center text-center">
          <Image
            src="/logo-mark.png"
            alt=""
            width={56}
            height={56}
            className="mb-4 size-14 rounded-2xl shadow-raised"
            priority
          />
          <h1 className="text-xl font-semibold tracking-tight text-ink">
            Vision Connect
          </h1>
          <p className="mt-1 text-sm text-ink-soft">
            Sign in to the admin panel
          </p>
        </div>

        <div className="card p-6">
          <form action={formAction} className="space-y-4">
            {state.error ? (
              <div
                role="alert"
                className="flex items-start gap-2.5 rounded-lg border border-bad/25 bg-bad-soft px-3.5 py-3 text-sm text-bad"
              >
                <span className="mt-px shrink-0">
                  <IconAlert size={16} />
                </span>
                {state.error}
              </div>
            ) : null}

            <div>
              <label className="field-label" htmlFor="email">
                Email
              </label>
              <input
                id="email"
                name="email"
                type="email"
                autoComplete="username"
                required
                autoFocus
                className="field"
                placeholder="you@company.com"
              />
            </div>

            <div>
              <label className="field-label" htmlFor="password">
                Password
              </label>
              <input
                id="password"
                name="password"
                type="password"
                autoComplete="current-password"
                required
                className="field"
                placeholder="••••••••"
              />
            </div>

            <SubmitButton />
          </form>
        </div>

        <div className="mt-6 flex items-center justify-between gap-4">
          <p className="text-xs text-ink-muted">
            Admin access only. App users sign in from the mobile app.
          </p>
          <div className="w-28 shrink-0">
            <ThemeToggle />
          </div>
        </div>
      </div>
    </main>
  );
}
