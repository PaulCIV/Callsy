import mongoose, { Schema } from "mongoose";

const CallEventSchema = new Schema(
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

    // Twilio identifiers
    callSid: { type: String, required: true, index: true },

    from: { type: String, required: true, trim: true },
    to: { type: String, required: true, trim: true },

    callStatus: { type: String, required: true, trim: true },
    direction: { type: String, trim: true },

    duration: { type: Number },
    answeredBy: { type: String, trim: true },

    consent: {
      status: {
        type: String,
        enum: ["pending", "granted", "declined", "no_response"],
        default: "pending"
      },
      method: { type: String, enum: ["keypress", "speech", ""], default: "" },
      response: { type: String, trim: true, default: "" },
      disclosureVersion: { type: String, trim: true, default: "missed-call-sms-v1" },
      requestedAt: { type: Date },
      resolvedAt: { type: Date }
    },

    callbackRequired: { type: Boolean, default: false },

    raw: { type: Schema.Types.Mixed }
  } as any),
  { timestamps: true }
);

CallEventSchema.index({ businessId: 1, callSid: 1 }, { unique: true });

export const CallEvent =
  (mongoose.models.CallEvent as any) || mongoose.model("CallEvent", CallEventSchema);
