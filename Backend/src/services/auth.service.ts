import bcrypt from "bcryptjs";
import { User } from "../models/user";
import { Business } from "../models/business";

function normalizeEmail(email: string) {
  return email.trim().toLowerCase();
}

function makeHttpError(message: string, status: number) {
  const err = new Error(message) as Error & { status?: number };
  err.status = status;
  return err;
}

function toSafeUser(user: any) {
  return {
    _id: String(user._id),
    email: String(user.email)
  };
}

export async function signup(emailRaw: string, password: string) {
  const email = normalizeEmail(emailRaw);

  const existing = await User.findOne({ email });
  if (existing) {
    throw makeHttpError("Email already in use", 409);
  }

  const passwordHash = await bcrypt.hash(password, 12);
  const user = await User.create({ email, passwordHash });

  // Create a starter business automatically for the new user
  await Business.create({
    ownerId: user._id,
    name: "My Business"
  });

  return {
    user: toSafeUser(user)
  };
}

export async function login(emailRaw: string, password: string) {
  const email = normalizeEmail(emailRaw);

  const user = await User.findOne({ email });
  if (!user) {
    throw makeHttpError("Invalid email or password", 401);
  }

  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) {
    throw makeHttpError("Invalid email or password", 401);
  }

  return {
    user: toSafeUser(user)
  };
}