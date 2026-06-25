import { Request, Response } from "express";
import jwt from "jsonwebtoken";
import { signup, login } from "../services/auth.service";

function isValidEmail(email: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function getJwtSecret(): string {
  const secret = process.env.JWT_SECRET;
  if (!secret || !secret.trim()) {
    throw new Error("Missing JWT_SECRET");
  }
  return secret;
}

function setSessionCookie(res: Response, user: any) {
  const token = jwt.sign(
    {
      userId: String(user._id),
      email: user.email
    },
    getJwtSecret(),
    { expiresIn: "7d" }
  );

  res.cookie("callsy_session", token, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    maxAge: 7 * 24 * 60 * 60 * 1000
  });
}

export async function signupHandler(req: Request, res: Response) {
  const { email, password } = req.body ?? {};

  if (typeof email !== "string" || !isValidEmail(email)) {
    return res.status(400).json({ error: "Valid email is required" });
  }

  if (typeof password !== "string" || password.length < 8) {
    return res.status(400).json({
      error: "Password must be at least 8 characters"
    });
  }

  const result = await signup(email, password);
  const user = result?.user ?? result;

  setSessionCookie(res, user);

  return res.status(201).json({
    ok: true,
    user
  });
}

export async function loginHandler(req: Request, res: Response) {
  const { email, password } = req.body ?? {};

  if (typeof email !== "string" || !isValidEmail(email)) {
    return res.status(400).json({ error: "Valid email is required" });
  }

  if (typeof password !== "string" || password.length === 0) {
    return res.status(400).json({ error: "Password is required" });
  }

  const result = await login(email, password);
  const user = result?.user ?? result;

  setSessionCookie(res, user);

  return res.status(200).json({
    ok: true,
    user
  });
}

export async function logoutHandler(_req: Request, res: Response) {
  res.clearCookie("callsy_session", {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production"
  });

  return res.status(200).json({ ok: true });
}

export async function meHandler(req: Request, res: Response) {
  const user = (req as any).user;

  if (!user) {
    return res.status(401).json({ error: "Not authenticated" });
  }

  return res.status(200).json({
    ok: true,
    user
  });
}