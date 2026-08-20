'use client';

import { useActionState } from 'react';
import { useFormStatus } from 'react-dom';

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
    <main className="flex flex-1 items-center justify-center p-6">
      <div className="w-full max-w-md rounded-2xl border border-line bg-surface p-8 shadow-sm">
        <div className="mb-6 flex flex-col items-center text-center">
          <span className="mb-4 inline-flex size-16 items-center justify-center rounded-2xl bg-brand-500 text-2xl text-white">
            ☎
          </span>
          <h1 className="text-2xl font-extrabold tracking-tight">
            Business Connect
          </h1>
          <p className="mt-1 text-sm text-ink-soft">
            Admin panel — sign in to manage numbers and users.
          </p>
        </div>

        <form action={formAction} className="space-y-4">
          {state.error ? (
            <div className="rounded-lg border border-bad/30 bg-bad-soft px-4 py-3 text-sm text-bad">
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
              className="field"
              placeholder="admin@businessconnect.local"
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
    </main>
  );
}
