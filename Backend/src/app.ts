import express from "express";
import cors from "cors";
import { env } from "./config/env";
import healthRoutes from "./routes/health.routes";
import twilioRoutes from "./routes/twilio.routes";
import authRoutes from "./routes/auth.routes";
import { notFound } from "./middleware/notFound.middleware";
import { errorMiddleware } from "./middleware/error.middleware";

import cookieParser from "cookie-parser";



const app = express();

app.use(
  cors({
    origin: env.FRONTEND_ORIGIN,
    credentials: true
  })
);

app.use(cookieParser());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use("/", healthRoutes);
app.use("/", twilioRoutes);

// ✅ Auth
app.use("/auth", authRoutes);

app.use(notFound);
app.use(errorMiddleware);

export default app;