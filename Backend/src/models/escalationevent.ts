import mongoose, { Schema } from "mongoose";

const EscalationAttemptSchema = new Schema(
  {
    role: { type: String, enum: ["primary", "backup"], required: true },
    phone: { type: String, required: true, trim: true },
    callSid: { type: String, trim: true, index: true },
    status: { type: String, trim: true, default: "queued" },
    startedAt: { type: Date, default: Date.now },
    completedAt: { type: Date }
  },
  { _id: false }
);

const EscalationEventSchema = new Schema(
  {
    businessId: { type: Schema.Types.ObjectId, ref: "Business", required: true, index: true },
    leadId: { type: Schema.Types.ObjectId, ref: "Lead", required: true, index: true },
    customerPhone: { type: String, required: true, trim: true },
    customerMessage: { type: String, required: true, trim: true },
    reason: { type: String, required: true, trim: true },
    summary: { type: String, required: true, trim: true },
    status: {
      type: String,
      enum: ["calling", "acknowledged", "unanswered", "failed"],
      default: "calling",
      index: true
    },
    acknowledgedBy: { type: String, trim: true, default: "" },
    acknowledgedAt: { type: Date },
    attempts: { type: [EscalationAttemptSchema], default: [] }
  },
  { timestamps: true }
);

EscalationEventSchema.index({ businessId: 1, createdAt: -1 });

export const EscalationEvent =
  (mongoose.models.EscalationEvent as mongoose.Model<any>) ||
  mongoose.model<any>("EscalationEvent", EscalationEventSchema);
