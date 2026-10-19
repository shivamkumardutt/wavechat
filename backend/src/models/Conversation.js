
import mongoose from "mongoose";

const conversationSchema = new mongoose.Schema(
  {
    conversationId: {
      type: String,
      required: true,
      trim: true,
      maxlength: 100,
      unique: true,
    },
    members: {
      type: [String],
      required: true,
      validate: {
        validator(members) {
          return (
            members.length >= 1 &&
            members.length <= 100 &&
            members.every(
              (member) =>
                typeof member === "string" &&
                member.length > 0,
            ) &&
            new Set(members).size === members.length
          );
        },
        message: "A conversation requires unique member IDs.",
      },
    },
  },
  { timestamps: true },
);

export default mongoose.model("Conversation", conversationSchema);
