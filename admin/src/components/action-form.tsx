'use client';

import {
  useActionState,
  useState,
  useTransition,
  type ReactNode,
} from 'react';
import { useFormStatus } from 'react-dom';

import { IconPlus } from './icons';

export type ActionState = { ok?: string; error?: string };
export type ServerAction = (
  state: ActionState,
  formData: FormData,
) => Promise<ActionState>;

function Submit({
  label,
  pendingLabel,
  variant = 'primary',
  className = '',
  confirm,
}: {
  label: string;
  pendingLabel?: string;
  variant?: 'primary' | 'secondary' | 'danger' | 'ghost';
  className?: string;
  confirm?: string;
}) {
  const { pending } = useFormStatus();
  const variants = {
    primary: 'btn-primary',
    secondary: 'btn-secondary',
    danger: 'btn-danger',
    ghost: 'btn-ghost',
  } as const;

  return (
    <button
      type="submit"
      disabled={pending}
      className={`${variants[variant]} ${className}`}
      onClick={(event) => {
        if (confirm && !window.confirm(confirm)) event.preventDefault();
      }}
    >
      {pending ? (pendingLabel ?? 'Working…') : label}
    </button>
  );
}

/**
 * Actions call `revalidatePath`, which re-renders the page and clears the
 * state `useActionState` returned. Mirroring it into component state keeps the
 * success or error message on screen after the table behind it updates.
 */
function useStickyState(state: ActionState): ActionState {
  const [sticky, setSticky] = useState<ActionState>({});
  const [seen, setSeen] = useState(state);

  // Adjusting state during render (rather than in an effect) so the message is
  // correct on the very first paint after the action resolves.
  if (seen !== state) {
    setSeen(state);
    if (state.ok || state.error) setSticky(state);
  }

  return state.ok || state.error ? state : sticky;
}

/** Form wired to a server action, with inline success/error feedback. */
export function ActionForm({
  action,
  children,
  submitLabel,
  pendingLabel,
  variant = 'primary',
  className = '',
  submitClassName = '',
  confirm,
  hideFeedback = false,
}: {
  action: ServerAction;
  children?: ReactNode;
  submitLabel: string;
  pendingLabel?: string;
  variant?: 'primary' | 'secondary' | 'danger' | 'ghost';
  className?: string;
  submitClassName?: string;
  confirm?: string;
  hideFeedback?: boolean;
}) {
  const [state, formAction] = useActionState<ActionState, FormData>(action, {});
  const feedback = useStickyState(state);

  return (
    <form action={formAction} className={className}>
      {!hideFeedback && feedback.error ? (
        <p
          role="alert"
          className="mb-4 rounded-lg border border-bad/25 bg-bad-soft px-3.5 py-2.5 text-sm text-bad"
        >
          {feedback.error}
        </p>
      ) : null}
      {!hideFeedback && feedback.ok ? (
        <p
          role="status"
          className="mb-4 rounded-lg border border-ok/25 bg-ok-soft px-3.5 py-2.5 text-sm text-ok"
        >
          {feedback.ok}
        </p>
      ) : null}

      {children}

      <Submit
        label={submitLabel}
        pendingLabel={pendingLabel}
        variant={variant}
        className={submitClassName}
        confirm={confirm}
      />
    </form>
  );
}

/**
 * Number-to-user picker that saves as soon as the selection changes.
 *
 * It calls the server action directly rather than through a `<form>`: React 19
 * resets a form after its action resolves, which would snap the dropdown back
 * to the option the server first rendered even though the change was saved.
 */
export function AssignSelect({
  action,
  numberId,
  currentUserId,
  users,
}: {
  action: ServerAction;
  numberId: string;
  currentUserId: string | null;
  users: { id: string; name: string }[];
}) {
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [value, setValue] = useState(currentUserId ?? '');
  const [seenOwner, setSeenOwner] = useState(currentUserId);

  // Re-sync when the server reports a different owner (e.g. another admin tab).
  if (seenOwner !== currentUserId) {
    setSeenOwner(currentUserId);
    setValue(currentUserId ?? '');
  }

  function assign(next: string) {
    const previous = value;
    setValue(next);
    setError(null);

    const data = new FormData();
    data.set('numberId', numberId);
    data.set('assignedTo', next);

    startTransition(async () => {
      const result = await action({}, data);
      if (result.error) {
        setError(result.error);
        setValue(previous);
      }
    });
  }

  return (
    <div className="flex flex-col gap-1">
      <select
        name="assignedTo"
        aria-label="Assigned to"
        value={value}
        disabled={pending}
        onChange={(event) => assign(event.target.value)}
        className="field max-w-52 py-1.5 text-sm"
      >
        <option value="">— Unassigned —</option>
        {users.map((user) => (
          <option key={user.id} value={user.id}>
            {user.name}
          </option>
        ))}
      </select>
      {error ? (
        <span role="alert" className="text-xs font-semibold text-bad">
          {error}
        </span>
      ) : null}
    </div>
  );
}

/**
 * Collapsible panel used for the "add" forms on list pages. The open state is
 * held in React so a server action's re-render cannot snap it shut and hide
 * the success or error message the form just produced.
 */
export function Disclosure({
  label,
  description,
  children,
}: {
  label: string;
  description?: string;
  children: ReactNode;
}) {
  const [open, setOpen] = useState(false);

  return (
    <div className="card overflow-hidden">
      <button
        type="button"
        aria-expanded={open}
        onClick={() => setOpen((value) => !value)}
        className="flex w-full items-center justify-between gap-3 px-5 py-4 text-left transition-colors hover:bg-sunken"
      >
        <span className="min-w-0">
          <span className="block text-[15px] font-semibold tracking-tight text-ink">
            {label}
          </span>
          {description ? (
            <span className="mt-0.5 block text-sm text-ink-soft">
              {description}
            </span>
          ) : null}
        </span>
        <span
          className={`shrink-0 rounded-md border border-line bg-surface p-1.5 text-ink-soft transition-transform ${
            open ? 'rotate-45' : ''
          }`}
        >
          <IconPlus size={16} />
        </span>
      </button>
      {open ? <div className="border-t border-line p-5">{children}</div> : null}
    </div>
  );
}
