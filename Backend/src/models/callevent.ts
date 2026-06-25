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

    raw: { type: Schema.Types.Mixed }
  } as any),
  { timestamps: true }
);

CallEventSchema.index({ businessId: 1, callSid: 1 }, { unique: true });

export const CallEvent =
  (mongoose.models.CallEvent as any) || mongoose.model("CallEvent", CallEventSchema);