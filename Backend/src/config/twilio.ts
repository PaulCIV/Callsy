import twilio from "twilio";
import { env } from "./env";

export const twilioClient = env.TWILIO_API_KEY_SID && env.TWILIO_API_KEY_SECRET
  ? twilio(env.TWILIO_API_KEY_SID, env.TWILIO_API_KEY_SECRET, {
      accountSid: env.TWILIO_ACCOUNT_SID
    })
  : twilio(env.TWILIO_ACCOUNT_SID, env.TWILIO_AUTH_TOKEN);
