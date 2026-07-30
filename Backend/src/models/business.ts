import mongoose from "mongoose";

const { Schema } = mongoose;

const BusinessSchema = new Schema<any>(
  {
    ownerId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true
    },

    name: {
      type: String,
      required: true,
      trim: true
    },

    businessType: {
      type: String,
      trim: true
    },

    businessDescription: {
      type: String,
      trim: true
    },

    tone: {
      type: String,
      enum: ["friendly", "professional", "casual", "direct"],
      default: "friendly"
    },

    firstResponseStyle: {
      type: String,
      enum: ["conversational", "menu", "appointment"],
      default: "conversational"
    },

    menuOptions: {
      type: [String],
      default: []
    },

    useAiGeneratedMessage: {
      type: Boolean,
      default: true
    },

    forwardToNumber: { type: String, trim: true },
    twilioNumber: { type: String, trim: true },
    twilioPhoneSid: { type: String, trim: true },

    notifyToNumber: { type: String, trim: true },
    destinationNumber: { type: String, trim: true },

    bookingLink: { type: String, trim: true },

    callHandlingMode: {
      type: String,
      trim: true,
      default: "FORWARD_ON_MISS"
    },

    onboardingStatus: {
      type: String,
      trim: true,
      default: "draft"
    },

    followupTemplate: {
      type: String,
      trim: true,
      default:
        "Hi — this is {{business}}. Sorry we missed your call. How can we help?"
    },

    aiConfig: {
      enabled: { type: Boolean, default: true },
      classifyLeads: { type: Boolean, default: true },
      autoFollowupEnabled: { type: Boolean, default: true },
      conversationRepliesEnabled: { type: Boolean, default: true }
    },

    priorityEscalation: {
      enabled: { type: Boolean, default: false },
      primaryPhone: { type: String, trim: true, default: "" },
      backupPhone: { type: String, trim: true, default: "" },
      urgentKeywords: {
        type: [String],
        default: ["tow", "towing", "stranded", "broke down", "roadside", "accident"]
      },
      ringTimeoutSeconds: { type: Number, default: 20 },
      customerConfirmationEnabled: { type: Boolean, default: true }
    },

    isActive: { type: Boolean, default: true },
    cooldownMinutes: { type: Number, default: 120 }
  },
  { timestamps: true }
);

BusinessSchema.index(
  { twilioNumber: 1 },
  {
    unique: true,
    partialFilterExpression: {
      twilioNumber: { $type: "string", $gt: "" }
    }
  }
);

BusinessSchema.index(
  { twilioPhoneSid: 1 },
  {
    unique: true,
    partialFilterExpression: {
      twilioPhoneSid: { $type: "string", $gt: "" }
    }
  }
);

const Business =
  (mongoose.models.Business as mongoose.Model<any>) ||
  mongoose.model<any>("Business", BusinessSchema);

export { Business };
