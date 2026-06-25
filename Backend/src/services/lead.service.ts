import { Lead } from "../models/lead";

export async function upsertLead(businessId: string, phone: string) {
  const now = new Date();

  return Lead.findOneAndUpdate(
    { businessId, phone },
    {
      $setOnInsert: {
        businessId,
        phone,
        status: "new",
        firstSeenAt: now,
        smsReplyCount: 0,
        "followup.sent": false,
        "followup.blocked": false
      },
      $set: {
        lastSeenAt: now,
        lastMessageDirection: "inbound_call"
      },
      $inc: {
        callCount: 1
      }
    },
    { new: true, upsert: true }
  );
}

export async function upsertSmsLead(businessId: string, phone: string) {
  const now = new Date();

  return Lead.findOneAndUpdate(
    { businessId, phone },
    {
      $setOnInsert: {
        businessId,
        phone,
        status: "new",
        firstSeenAt: now,
        callCount: 0,
        "followup.sent": false,
        "followup.blocked": false
      },
      $set: {
        lastSeenAt: now,
        lastMessageDirection: "inbound_sms"
      }
    },
    { new: true, upsert: true }
  );
}

export async function markCustomerReply(leadId: string, message: string) {
  const now = new Date();

  await Lead.updateOne(
    { _id: leadId },
    {
      $inc: {
        smsReplyCount: 1
      },
      $set: {
        lastSeenAt: now,
        lastCustomerMessage: message,
        lastMessageDirection: "inbound_sms"
      }
    }
  );
}

export function isCooldownActive(
  lastFollowupAt: Date | undefined,
  cooldownMinutes: number
) {
  if (!lastFollowupAt) return false;

  const diff = Date.now() - new Date(lastFollowupAt).getTime();
  return diff < cooldownMinutes * 60 * 1000;
}

export async function markFollowupSent(
  leadId: string,
  message: string,
  style = "auto"
) {
  const now = new Date();

  await Lead.updateOne(
    { _id: leadId },
    {
      $set: {
        lastFollowupAt: now,
        lastSeenAt: now,
        status: "contacted",
        lastMessageDirection: "outbound_sms",
        "followup.sent": true,
        "followup.sentAt": now,
        "followup.message": message,
        "followup.style": style,
        "followup.blocked": false,
        "followup.blockedReason": ""
      }
    }
  );
}

export async function markFollowupBlocked(leadId: string, reason: string) {
  await Lead.updateOne(
    { _id: leadId },
    {
      $set: {
        "followup.blocked": true,
        "followup.blockedReason": reason
      }
    }
  );
}