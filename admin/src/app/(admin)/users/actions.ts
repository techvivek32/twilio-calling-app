'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';

import { hashPassword, requireAdmin } from '@/lib/auth';
import { connectToDatabase } from '@/lib/db';
import { CallLog, Contact, MessageLog, PhoneNumber, User } from '@/lib/models';

export type ActionState = { ok?: string; error?: string };

function text(formData: FormData, key: string): string {
  return String(formData.get(key) ?? '').trim();
}

function refresh() {
  revalidatePath('/users');
  revalidatePath('/numbers');
  revalidatePath('/dashboard');
}

export async function createUserAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  try {
    await requireAdmin();
    await connectToDatabase();

    const name = text(formData, 'name');
    const email = text(formData, 'email').toLowerCase();
    const password = String(formData.get('password') ?? '');
    const role = text(formData, 'role') === 'admin' ? 'admin' : 'user';
    const numberId = text(formData, 'numberId');

    if (!name || !email || !password) {
      return { error: 'Name, email and password are all required.' };
    }
    if (password.length < 8) {
      return { error: 'Password must be at least 8 characters.' };
    }
    if (await User.findOne({ email })) {
      return { error: `${email} is already registered.` };
    }

    const user = await User.create({
      name,
      email,
      passwordHash: await hashPassword(password),
      role,
      status: 'active',
    });

    if (numberId) {
      await PhoneNumber.updateMany(
        { assignedTo: user._id },
        { assignedTo: null, assignedAt: null },
      );
      await PhoneNumber.updateOne(
        { _id: numberId },
        { assignedTo: user._id, assignedAt: new Date() },
      );
    }

    refresh();
    return { ok: `Created ${name}.` };
  } catch (error) {
    return { error: (error as Error).message };
  }
}

export async function updateUserAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  try {
    await requireAdmin();
    await connectToDatabase();

    const id = text(formData, 'id');
    const name = text(formData, 'name');
    const email = text(formData, 'email').toLowerCase();
    const role = text(formData, 'role') === 'admin' ? 'admin' : 'user';
    const status = text(formData, 'status') === 'suspended' ? 'suspended' : 'active';
    const password = String(formData.get('password') ?? '');

    const user = await User.findById(id);
    if (!user) return { error: 'User not found.' };

    if (email !== user.email) {
      const clash = await User.findOne({ email, _id: { $ne: id } });
      if (clash) return { error: `${email} is already registered.` };
    }

    // Never let the last admin lock everyone out of the panel.
    if (user.role === 'admin' && (role !== 'admin' || status !== 'active')) {
      const otherAdmins = await User.countDocuments({
        role: 'admin',
        status: 'active',
        _id: { $ne: user._id },
      });
      if (otherAdmins === 0) {
        return { error: 'This is the only active admin — keep it enabled.' };
      }
    }

    user.name = name || user.name;
    user.email = email || user.email;
    user.role = role;
    user.status = status;
    if (password) {
      if (password.length < 8) {
        return { error: 'Password must be at least 8 characters.' };
      }
      user.passwordHash = await hashPassword(password);
    }
    await user.save();

    refresh();
    revalidatePath(`/users/${id}`);
    return { ok: 'Changes saved.' };
  } catch (error) {
    return { error: (error as Error).message };
  }
}

export async function deleteUserAction(
  _prev: ActionState,
  formData: FormData,
): Promise<ActionState> {
  let deletedName: string | null = null;

  try {
    const session = await requireAdmin();
    await connectToDatabase();

    const id = text(formData, 'id');
    if (id === session.sub) {
      return { error: 'You cannot delete the account you are signed in with.' };
    }

    const user = await User.findById(id);
    if (!user) return { error: 'User not found.' };

    if (user.role === 'admin') {
      const otherAdmins = await User.countDocuments({
        role: 'admin',
        status: 'active',
        _id: { $ne: user._id },
      });
      if (otherAdmins === 0) return { error: 'Cannot delete the last admin.' };
    }

    // Free the number first so it can be handed to someone else.
    await PhoneNumber.updateMany(
      { assignedTo: user._id },
      { assignedTo: null, assignedAt: null },
    );
    await Promise.all([
      CallLog.deleteMany({ userId: user._id }),
      MessageLog.deleteMany({ userId: user._id }),
      Contact.deleteMany({ userId: user._id }),
    ]);
    await user.deleteOne();
    deletedName = user.name;

    refresh();
  } catch (error) {
    return { error: (error as Error).message };
  }

  // The detail page for this id no longer resolves, so send the admin back to
  // the list rather than leaving them on a 404. `redirect` throws, so it has
  // to run outside the try/catch above.
  if (deletedName) redirect('/users');
  return {};
}
