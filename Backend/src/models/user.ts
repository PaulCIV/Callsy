import mongoose, { Schema } from "mongoose";

export type UserDoc = mongoose.Document & {
  email: string;
  passwordHash: string;
  createdAt: Date;
  updatedAt: Date;
};

const userSchema = new Schema(
  {
    email: { type: String, required: true, lowercase: true, trim: true },
    passwordHash: { type: String, required: true }
  },
  { timestamps: true }
);

// Helpful index
userSchema.index({ email: 1 }, { unique: true });

export const User =
  (mongoose.models.User as any) || mongoose.model("User", userSchema);
