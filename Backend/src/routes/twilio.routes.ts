import { Router } from "express";
import {
  voiceWebhook,
  callStatusWebhook,
  smsInboundWebhook
} from "../controllers/twilio.controller";

const router = Router();

// Twilio will POST to these
router.post("/twilio/voice", voiceWebhook);
router.post("/twilio/call-status", callStatusWebhook);
router.post("/twilio/sms-inbound", smsInboundWebhook);

export default router;