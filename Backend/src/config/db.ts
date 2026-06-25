import mongoose from "mongoose";
import { env } from "./env";

export async function connectDb(): Promise<void> {
  mongoose.set("strictQuery", true);

  await mongoose.connect(env.MONGODB_URI);

  console.log("✅ MongoDB connected");
}

export async function disconnectDb(): Promise<void> {
  await mongoose.disconnect();
  console.log("🛑 MongoDB disconnected");
}