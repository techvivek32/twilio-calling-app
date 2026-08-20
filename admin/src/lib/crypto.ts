import crypto from 'node:crypto';

const ALGORITHM = 'aes-256-gcm';

function key(): Buffer {
  const raw = process.env.APP_ENCRYPTION_KEY;
  if (!raw || raw.length !== 64) {
    throw new Error(
      'APP_ENCRYPTION_KEY must be 64 hex characters (32 bytes). See .env.example.',
    );
  }
  return Buffer.from(raw, 'hex');
}

/** Encrypts a secret for storage. Returns `iv.tag.ciphertext`, all base64url. */
export function encryptSecret(plain: string): string {
  if (!plain) return '';
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv(ALGORITHM, key(), iv);
  const ciphertext = Buffer.concat([
    cipher.update(plain, 'utf8'),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();
  return [iv, tag, ciphertext]
    .map((part) => part.toString('base64url'))
    .join('.');
}

/** Reverses {@link encryptSecret}. Returns '' when the value is absent. */
export function decryptSecret(stored: string): string {
  if (!stored) return '';
  const [ivPart, tagPart, dataPart] = stored.split('.');
  if (!ivPart || !tagPart || !dataPart) return '';

  try {
    const decipher = crypto.createDecipheriv(
      ALGORITHM,
      key(),
      Buffer.from(ivPart, 'base64url'),
    );
    decipher.setAuthTag(Buffer.from(tagPart, 'base64url'));
    return Buffer.concat([
      decipher.update(Buffer.from(dataPart, 'base64url')),
      decipher.final(),
    ]).toString('utf8');
  } catch {
    // Wrong key or tampered value — treat as unset rather than crashing a page.
    return '';
  }
}

/** Shows only the last 4 characters of a secret, e.g. `••••••••3f2a`. */
export function maskSecret(value: string): string {
  if (!value) return '';
  if (value.length <= 4) return '••••';
  return `${'•'.repeat(8)}${value.slice(-4)}`;
}
