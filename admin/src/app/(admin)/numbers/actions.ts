'use server';

import { revalidatePath } from 'next/cache';

import { requireAdmin } from '@/lib/auth';
import { connectToDatabase } from '@/lib/db';
import { PhoneNumber, User } from '@/lib/models';
import { listRemoteNumbers, toE164 } from '@/lib/twilio';

export type ActionState = { ok?: string; error?: string };

function text(formData: FormData, key: string): string {
  return String(formData.get(key) ?? '').trim();
}

function refresh() {
  revalidatePath('/numbers');
  revalidatePath('/users');
  revalidatePath('/dashboard');
}

/**
 * Pulls every number owned by the Twilio account into Mongo. Existing rows are
 * updated in place so assignments survive a re-sync.
 */
export async function syncNumbersAction(
  _prev: ActionState,
  _formData: FormData,
): Promise<ActionState> {
  try {
    await requireAdmin();
    await connectToDatabase();

    const remote = await listRemoteNumbers();
    let created = 0;
    let updated = 0;

    for (const number of remote) {
      const existing = await PhoneNumber.findOne({
        $or: [{ sid: number.sid }, { phoneNumber: number.phoneNumber }],
      });

      if (existing) {
        existing.sid = number.sid;
        existing.phoneNumber = number.phoneNumber;
        existing.friendlyName = number.friendlyName;
        existing.capabilities = number.capabilities;
        existing.source = 'twilio';
        existing.lastSyncedAt = new Date();
        await existing.save();
        updated += 1;
      } else {
        await PhoneNumber.create({
          ...number,
          source: 'twilio',
          lastSyncedAt: new Date(),
        });
        created += 1;
      }
    }

    refresh();
    return {
      ok: `Synced ${remote.length} number(s) from Twilio — ${created} new, ${updated} updated.`,
    };
  } catch (error) {
    return { error: (error as Error).message };
  }
}

export async function addNumberAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  try {
    await requireAdmin();
    await connectToDatabase();

    const phoneNumber = toE164(text(formData, 'phoneNumber'));
    const friendlyName = text(formData, 'friendlyName');
    const userId = text(formData, 'assignedTo');

    if (!phoneNumber) return { error: 'Enter a phone number.' };
    if (await PhoneNumber.findOne({ phoneNumber })) {
      return { error: `${phoneNumber} is already in the list.` };
    }

    await PhoneNumber.create({
      phoneNumber,
      friendlyName: friendlyName || phoneNumber,
      source: 'manual',
      assignedTo: userId || null,
      assignedAt: userId ? new Date() : null,
    });

    refresh();
    return { ok: `Added ${phoneNumber}.` };
  } catch (error) {
    return { error: (error as Error).message };
  }
}

/** Assigns a number to a user, or releases it when `assignedTo` is empty. */
export async function assignNumberAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  try {
    await requireAdmin();
    await connectToDatabase();

    const numberId = text(formData, 'numberId');
    const userId = text(formData, 'assignedTo');

    const number = await PhoneNumber.findById(numberId);
    if (!number) return { error: 'Number not found.' };

    if (!userId) {
      number.assignedTo = null;
      number.assignedAt = null;
      await number.save();
      refresh();
      return { ok: `${number.phoneNumber} is now unassigned.` };
    }

    const user = await User.findById(userId);
    if (!user) return { error: 'User not found.' };

    number.assignedTo = user._id;
    number.assignedAt = new Date();
    await number.save();

    refresh();
    return { ok: `${number.phoneNumber} assigned to ${user.name}.` };
  } catch (error) {
    return { error: (error as Error).message };
  }
}

export async function setNumberStatusAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  try {
    await requireAdmin();
    await connectToDatabase();

    const numberId = text(formData, 'numberId');
    const status = text(formData, 'status') === 'inactive' ? 'inactive' : 'active';

    const number = await PhoneNumber.findByIdAndUpdate(
      numberId,
      { status },
      { new: true },
    );
    if (!number) return { error: 'Number not found.' };

    refresh();
    return { ok: `${number.phoneNumber} marked ${status}.` };
  } catch (error) {
    return { error: (error as Error).message };
  }
}

export async function deleteNumberAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  try {
    await requireAdmin();
    await connectToDatabase();

    const numberId = text(formData, 'numberId');
    const number = await PhoneNumber.findById(numberId);
    if (!number) return { error: 'Number not found.' };

    // Only removes the local record — the number stays on the Twilio account.
    await number.deleteOne();

    refresh();
    return { ok: `Removed ${number.phoneNumber} from the panel.` };
  } catch (error) {
    return { error: (error as Error).message };
  }
}
