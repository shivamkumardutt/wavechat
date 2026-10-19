
import mongoose from "mongoose";

const messageSchema = new mongoose.Schema(
  {
    clientMessageId: {
      type: String,
      required: true,
      trim: true,
      maxlength: 100,
    },
    conversationId: {
      type: String,
      required: true,
      trim: true,
      maxlength: 100,
      index: true,
    },
    senderId: {
      type: String,
      required: true,
      trim: true,
      maxlength: 100,
    },
    text: {
      type: String,
      required: true,
      trim: true,
      maxlength: 4000,
    },
  },
  {
    timestamps: { createdAt: true, updatedAt: false },
  },
);

messageSchema.index(
  { conversationId: 1, createdAt: -1 },
);

messageSchema.index(
  { conversationId: 1, senderId: 1, clientMessageId: 1 },
  { unique: true },
);

export default mongoose.model("Message", messageSchema);
