import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";
import { env } from "../config/env";

export type AuthedRequest = Request & {
  user?: {
    userId: string;
    email?: string;
  };
};

export function requireAuth(
  req: AuthedRequest,
  res: Response,
  next: NextFunction
) {
  const token = req.cookies?.callsy_session;

  if (!token) {
    return res.status(401).json({ error: "Not authenticated" });
  }

  try {
    const payload = jwt.verify(token, env.JWT_SECRET) as {
      userId: string;
      email?: string;
    };

    req.user = payload;

    return next();
  } catch {
    return res.status(401).json({ error: "Invalid or expired session" });
  }
}