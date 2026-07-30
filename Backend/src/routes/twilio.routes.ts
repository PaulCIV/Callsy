import { Router } from "express";
import {
  voiceWebhook,
  voiceConsentWebhook,
  callStatusWebhook,
  smsInboundWebhook,
  escalationResponseWebhook,
  escalationStatusWebhook
} from "../controllers/twilio.controller";

const router = Router();

// Twilio will POST to these
router.post("/twilio/voice", voiceWebhook);
router.post("/twilio/voice/consent", voiceConsentWebhook);
router.post("/twilio/call-status", callStatusWebhook);
router.post("/twilio/sms-inbound", smsInboundWebhook);
router.post("/twilio/escalations/:eventId/respond", escalationResponseWebhook);
router.post("/twilio/escalations/:eventId/status", escalationStatusWebhook);

export default router;
