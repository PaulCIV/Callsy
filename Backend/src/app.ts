import express from "express";
import path from "path";
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

// Expose the public legal pages through the same URL used for Twilio webhooks.
// This lets A2P reviewers open /privacy and /terms without accessing localhost.
const frontendDist = path.resolve(__dirname, "../../Frontend/dist");
app.use("/assets", express.static(path.join(frontendDist, "assets")));
app.get(["/privacy", "/terms"], (_req, res) => {
  res.sendFile(path.join(frontendDist, "index.html"));
});

app.use(notFound);
app.use(errorMiddleware);

export default app;
