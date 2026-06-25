import mongoose, { Schema } from "mongoose";

const SmsEventSchema = new Schema(
  ({
    businessId: {
      type: Schema.Types.ObjectId,
      ref: "Business",
      required: true,
      index: true
    },

    leadId: {
      type: Schema.Types.ObjectId,
      ref: "Lead",
      index: true
    },

    messageSid: {
      type: String,
      required: true,
      trim: true,
      index: true
    },

    direction: {
      type: String,
      required: true,
      trim: true
      // expected values:
      // "outbound-followup"
      // "outbound-manual"
      // "inbound-reply"
    },

    from: {
      type: String,
      required: true,
      trim: true,
      index: true
    },

    to: {
      type: String,
      required: true,
      trim: true,
      index: true
    },

    body: {
      type: String,
      required: true,
      trim: true
    },

    status: {
      type: String,
      trim: true
      // examples:
      // "queued"
      // "sent"
      // "delivered"
      // "received"
      // "failed"
    },

    errorCode: {
      type: String,
      trim: true
    },

    errorMessage: {
      type: String,
      trim: true
    },

    raw: {
      type: Schema.Types.Mixed
    }
  } as any),
  { timestamps: true }
);

// one Twilio message SID should only exist once
SmsEventSchema.index(
  { messageSid: 1 },
  {
    unique: true,
    partialFilterExpression: {
      messageSid: { $type: "string", $ne: "" }
    }
  }
);

export const SmsEvent =
  (mongoose.models.SmsEvent as any) || mongoose.model("SmsEvent", SmsEventSchema);