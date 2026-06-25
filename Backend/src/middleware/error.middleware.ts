import { Request, Response, NextFunction } from "express";

export function errorMiddleware(err: any, _req: Request, res: Response, _next: NextFunction) {
  const status = err?.status ?? 500;
  const message = err?.message ?? "Server error";

  if (status >= 500) {
    console.error("Server error:", err);
  }

  res.status(status).json({ error: message });
}