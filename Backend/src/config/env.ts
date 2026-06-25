// src/config/env.ts

import dotenv from "dotenv";

dotenv.config();

function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export const env = {
  NODE_ENV: process.env.NODE_ENV || "development",

  PORT: Number(process.env.PORT || 5000),

  MONGODB_URI: required("MONGODB_URI"),

  FRONTEND_ORIGIN: process.env.FRONTEND_ORIGIN || "",

  JWT_SECRET: required("JWT_SECRET"),
  JWT_EXPIRES_IN: process.env.JWT_EXPIRES_IN || "7d",

  TWILIO_ACCOUNT_SID: required("TWILIO_ACCOUNT_SID"),
  TWILIO_AUTH_TOKEN: required("TWILIO_AUTH_TOKEN"),
  TWILIO_PHONE_NUMBER: process.env.TWILIO_PHONE_NUMBER || "",

  // optional default sender override
  TWILIO_DEFAULT_FROM:
    process.env.TWILIO_DEFAULT_FROM || process.env.TWILIO_PHONE_NUMBER,

  PUBLIC_WEBHOOK_BASE_URL: process.env.PUBLIC_WEBHOOK_BASE_URL || "",

  TWILIO_NUMBER_COUNTRY: process.env.TWILIO_NUMBER_COUNTRY || "US",

  // ⭐ AI
  OPENAI_API_KEY: required("OPENAI_API_KEY")
};

function assertEnv() {
  const required = ["MONGODB_URI", "JWT_SECRET"] as const;
  for (const key of required) {
    if (!env[key] || env[key].trim() === "") {
      throw new Error(`Missing required env var: ${key}`);
    }
  }
}

assertEnv();