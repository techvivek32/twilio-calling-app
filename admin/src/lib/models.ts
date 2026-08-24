import mongoose, { Schema, type InferSchemaType, type Model } from 'mongoose';

/**
 * Mongoose re-registers models on hot reload, which throws. `model()` below
 * reuses an already-compiled model when one exists.
 */
function model<TSchema extends Schema>(
  name: string,
  schema: TSchema,
): Model<InferSchemaType<TSchema>> {
  return (mongoose.models[name] ??
    mongoose.model(name, schema)) as Model<InferSchemaType<TSchema>>;
}

const userSchema = new Schema(
  {
    name: { type: String, required: true, trim: true },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    passwordHash: { type: String, required: true },
    role: { type: String, enum: ['admin', 'user'], default: 'user' },
    // The user's own phone, in E.164. Click-to-call rings this first and then
    // bridges the far end to it, so the app needs no in-device audio stack.
    personalNumber: { type: String, default: '' },
    status: { type: String, enum: ['active', 'suspended'], default: 'active' },
    lastLoginAt: { type: Date, default: null },
  },
  { timestamps: true },
);

const phoneNumberSchema = new Schema(
  {
    // Twilio IncomingPhoneNumber SID; absent for numbers added by hand.
    sid: { type: String, default: null, index: true },
    phoneNumber: { type: String, required: true, unique: true, trim: true },
    friendlyName: { type: String, default: '' },
    capabilities: {
      voice: { type: Boolean, default: true },
      sms: { type: Boolean, default: true },
      mms: { type: Boolean, default: false },
    },
    assignedTo: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      default: null,
      index: true,
    },
    assignedAt: { type: Date, default: null },
    status: { type: String, enum: ['active', 'inactive'], default: 'active' },
    source: { type: String, enum: ['twilio', 'manual'], default: 'manual' },
    lastSyncedAt: { type: Date, default: null },
  },
  { timestamps: true },
);

const callLogSchema = new Schema(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    phoneNumberId: {
      type: Schema.Types.ObjectId,
      ref: 'PhoneNumber',
      default: null,
    },
    twilioSid: { type: String, default: null },
    from: { type: String, required: true },
    to: { type: String, required: true },
    contactName: { type: String, default: '' },
    direction: {
      type: String,
      enum: ['inbound', 'outbound'],
      required: true,
    },
    status: {
      type: String,
      enum: ['completed', 'missed', 'failed', 'busy', 'no-answer'],
      default: 'completed',
    },
    durationSec: { type: Number, default: 0 },
    // When the final status and duration were read back from Twilio. Unset
    // means the outcome is still provisional.
    twilioSyncedAt: { type: Date, default: null },
    startedAt: { type: Date, default: Date.now, index: true },
  },
  { timestamps: true },
);

const messageLogSchema = new Schema(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    phoneNumberId: {
      type: Schema.Types.ObjectId,
      ref: 'PhoneNumber',
      default: null,
    },
    twilioSid: { type: String, default: null },
    from: { type: String, required: true },
    to: { type: String, required: true },
    contactName: { type: String, default: '' },
    body: { type: String, default: '' },
    direction: {
      type: String,
      enum: ['inbound', 'outbound'],
      required: true,
    },
    status: {
      type: String,
      enum: ['queued', 'sent', 'delivered', 'failed', 'received'],
      default: 'sent',
    },
    // Null until the user opens the thread. The unread badge counts these, so
    // it can go down as well as up.
    readAt: { type: Date, default: null },
    sentAt: { type: Date, default: Date.now, index: true },
  },
  { timestamps: true },
);

const contactSchema = new Schema(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    name: { type: String, required: true, trim: true },
    phone: { type: String, required: true, trim: true },
    role: { type: String, default: '' },
    label: { type: String, default: 'Mobile' },
  },
  { timestamps: true },
);

/** Single document holding the Twilio integration configuration. */
const settingSchema = new Schema(
  {
    key: { type: String, default: 'twilio', unique: true },
    accountSid: { type: String, default: '' },
    // AES-256-GCM ciphertext; never returned to the browser in plain text.
    authTokenEnc: { type: String, default: '' },
    apiKeySid: { type: String, default: '' },
    apiKeySecretEnc: { type: String, default: '' },
    twimlAppSid: { type: String, default: '' },
    webhookBaseUrl: { type: String, default: '' },
    defaultCallerId: { type: String, default: '' },
    lastVerifiedAt: { type: Date, default: null },
    lastVerifyError: { type: String, default: '' },
  },
  { timestamps: true },
);

export const User = model('User', userSchema);
export const PhoneNumber = model('PhoneNumber', phoneNumberSchema);
export const CallLog = model('CallLog', callLogSchema);
export const MessageLog = model('MessageLog', messageLogSchema);
export const Contact = model('Contact', contactSchema);
export const Setting = model('Setting', settingSchema);

export type UserDoc = InferSchemaType<typeof userSchema> & { _id: string };
export type PhoneNumberDoc = InferSchemaType<typeof phoneNumberSchema> & {
  _id: string;
};
export type CallLogDoc = InferSchemaType<typeof callLogSchema> & {
  _id: string;
};
export type MessageLogDoc = InferSchemaType<typeof messageLogSchema> & {
  _id: string;
};
export type ContactDoc = InferSchemaType<typeof contactSchema> & {
  _id: string;
};
export type SettingDoc = InferSchemaType<typeof settingSchema> & {
  _id: string;
};
