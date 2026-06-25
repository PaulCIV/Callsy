import mongoose from "mongoose";

const { Schema } = mongoose;

const LeadSchema = new Schema<any>(
  {
    businessId: {
      type: Schema.Types.ObjectId,
      ref: "Business",
      required: true,
      index: true
    },

    phone: {
      type: String,
      required: true,
      trim: true,
      index: true
    },

    firstSeenAt: { type: Date, default: Date.now },
    lastSeenAt: { type: Date, default: Date.now },

    callCount: { type: Number, default: 0 },
    smsReplyCount: { type: Number, default: 0 },

    lastFollowupAt: { type: Date },

    status: {
      type: String,
      trim: true,
      default: "new"
    },

    lastMessageDirection: {
      type: String,
      enum: ["inbound_call", "inbound_sms", "outbound_sms"],
      default: "inbound_call"
    },

    lastCustomerMessage: {
      type: String,
      trim: true,
      default: ""
    },

    classification: {
      category: {
        type: String,
        enum: ["lead", "existing_customer", "wrong_number", "spam", "unknown"],
        default: "unknown"
      },
      confidence: { type: Number, default: 0 },
      reason: { type: String, default: "" },
      shouldAutoFollowup: { type: Boolean, default: true },
      classifiedAt: { type: Date }
    },

    followup: {
      message: { type: String, default: "" },
      style: { type: String, default: "" },
      sent: { type: Boolean, default: false },
      sentAt: { type: Date },
      blocked: { type: Boolean, default: false },
      blockedReason: { type: String, default: "" }
    }
  },
  { timestamps: true }
);

LeadSchema.index({ businessId: 1, phone: 1 }, { unique: true });

LeadSchema.pre("save", function (next) {
  const lead = this as any;
  lead.lastSeenAt = new Date();
  next();
});

const Lead =
  (mongoose.models.Lead as mongoose.Model<any>) ||
  mongoose.model<any>("Lead", LeadSchema);

export { Lead };