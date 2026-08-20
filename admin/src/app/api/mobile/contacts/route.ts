import { NextResponse, type NextRequest } from 'next/server';

import { connectToDatabase } from '@/lib/db';
import { fail, json, readJson, requireMobileUser } from '@/lib/mobile';
import { Contact } from '@/lib/models';
import { toE164 } from '@/lib/twilio';

type ContactBody = {
  name?: string;
  phone?: string;
  role?: string;
  label?: string;
};

export async function GET(request: NextRequest) {
  const context = await requireMobileUser(request);
  if (context instanceof NextResponse) return context;

  await connectToDatabase();
  const contacts = await Contact.find({ userId: context.user.id })
    .sort({ name: 1 })
    .lean();

  return json({
    contacts: contacts.map((contact) => ({
      id: String(contact._id),
      name: contact.name,
      phone: contact.phone,
      role: contact.role ?? '',
      label: contact.label ?? 'Mobile',
    })),
  });
}

export async function POST(request: NextRequest) {
  const context = await requireMobileUser(request);
  if (context instanceof NextResponse) return context;

  const body = await readJson<ContactBody>(request);
  const name = (body?.name ?? '').trim();
  const phone = toE164(body?.phone ?? '');

  if (!name) return fail('A contact name is required.', 422);
  if (!phone) return fail('A valid phone number is required.', 422);

  await connectToDatabase();
  const existing = await Contact.findOne({ userId: context.user.id, phone });
  if (existing) return fail('That number is already in your contacts.', 409);

  const contact = await Contact.create({
    userId: context.user.id,
    name,
    phone,
    role: body?.role ?? '',
    label: body?.label ?? 'Mobile',
  });

  return json(
    {
      contact: {
        id: String(contact._id),
        name: contact.name,
        phone: contact.phone,
        role: contact.role,
        label: contact.label,
      },
    },
    201,
  );
}
