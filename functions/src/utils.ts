import * as bcrypt from 'bcrypt';

const SALT_ROUNDS = 10;

export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, SALT_ROUNDS);
}

export async function verifyPassword(password: string, hashOrPlain: string): Promise<boolean> {
  // If the stored string starts with $2b$, it's a bcrypt hash
  if (hashOrPlain.startsWith('$2b$') || hashOrPlain.startsWith('$2a$')) {
    return bcrypt.compare(password, hashOrPlain);
  }
  // Fallback for plaintext (migration)
  return password === hashOrPlain;
}
