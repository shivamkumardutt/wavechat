import { requireAuth } from "./middleware/auth.js";
import jwt from "jsonwebtoken";
import express from "express";
import helmet from "helmet";
import cors from "cors";
import bcrypt from "bcryptjs";
import Message from "./models/Message.js";
import User from "./models/User.js";
import Conversation from "./models/Conversation.js";

const app = express();

app.use(helmet());

app.use(
  cors({
    origin: process.env.CORS_ORIGIN
      ? process.env.CORS_ORIGIN.split(",").map((value) => value.trim())
      : false,
  }),
);

app.use(express.json({ limit: "1mb" }));
app.use((req, res, next) => {
  const startedAt = Date.now();

  res.on("finish", () => {
    console.log(
      `[API] ${req.method} ${req.originalUrl} -> ${res.statusCode} (${Date.now() - startedAt}ms)`
    );
  });

  next();
});
app.get("/api/v1/health", (_req, res) => {
  res.status(200).json({
    status: "ok",
    service: "wavechat-api",
  });
});


app.post("/api/v1/auth/register", async (req, res) => {
  const name =
    typeof req.body?.name === "string"
      ? req.body.name.trim()
      : "";

  const email =
    typeof req.body?.email === "string"
      ? req.body.email.trim().toLowerCase()
      : "";

  const password =
    typeof req.body?.password === "string"
      ? req.body.password
      : "";

  if (name.length < 2 || name.length > 50) {
    return res.status(400).json({
      error: {
        code: "INVALID_NAME",
        message: "Name must be between 2 and 50 characters.",
      },
    });
  }

  if (
    email.length > 254 ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  ) {
    return res.status(400).json({
      error: {
        code: "INVALID_EMAIL",
        message: "A valid email address is required.",
      },
    });
  }

  if (password.length < 8 || password.length > 128) {
    return res.status(400).json({
      error: {
        code: "INVALID_PASSWORD",
        message: "Password must be between 8 and 128 characters.",
      },
    });
  }

  try {
    const passwordHash = await bcrypt.hash(password, 12);

    const user = await User.create({
      name,
      email,
      passwordHash,
    });

    return res.status(201).json({
      user: {
        id: user._id.toString(),
        name: user.name,
        email: user.email,
      },
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        error: {
          code: "EMAIL_ALREADY_REGISTERED",
          message: "An account with this email already exists.",
        },
      });
    }

    console.error("Registration failed:", error.message);

    return res.status(500).json({
      error: {
        code: "REGISTRATION_FAILED",
        message: "Unable to register account.",
      },
    });
  }
});


app.post("/api/v1/auth/login", async (req, res) => {
  const email =
    typeof req.body?.email === "string"
      ? req.body.email.trim().toLowerCase()
      : "";

  const password =
    typeof req.body?.password === "string"
      ? req.body.password
      : "";

  if (!email || !password) {
    return res.status(400).json({
      error: {
        code: "MISSING_CREDENTIALS",
        message: "Email and password are required.",
      },
    });
  }

  try {
    const user = await User.findOne({ email }).select("+passwordHash");

    if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
      return res.status(401).json({
        error: {
          code: "INVALID_CREDENTIALS",
          message: "Invalid email or password.",
        },
      });
    }

    const secret = process.env.JWT_SECRET;

    if (!secret || secret.length < 32) {
      console.error("JWT_SECRET is missing or too short.");

      return res.status(500).json({
        error: {
          code: "AUTH_CONFIGURATION_ERROR",
          message: "Authentication is not configured.",
        },
      });
    }

    const token = jwt.sign(
      { sub: user._id.toString() },
      secret,
      { expiresIn: "1h", issuer: "wavechat-api", audience: "wavechat-app" },
    );

    return res.status(200).json({
      token,
      tokenType: "Bearer",
      expiresIn: 3600,
      user: {
        id: user._id.toString(),
        name: user.name,
        email: user.email,
      },
    });
  } catch (error) {
    console.error("Login failed:", error.message);

    return res.status(500).json({
      error: {
        code: "LOGIN_FAILED",
        message: "Unable to log in.",
      },
    });
  }
});


function serializeMessage(message, replyToMessage = null) {
  return {
    id: message._id.toString(),
    clientMessageId: message.clientMessageId,
    conversationId: message.conversationId,
    senderId: message.senderId,
    text: message.text,
    replyToMessageId: message.replyToMessageId ?? null,
    replyTo: replyToMessage
      ? {
          id: replyToMessage._id.toString(),
          senderId: replyToMessage.senderId,
          text: replyToMessage.text,
        }
      : null,
    createdAt: message.createdAt.toISOString(),
  };
}

/**
 * Create or retrieve a one-to-one conversation.
 * Requires the authenticated user's Bearer token.
 */
app.post("/api/v1/conversations", requireAuth, async (req, res) => {
  const email =
    typeof req.body?.email === "string"
      ? req.body.email.trim().toLowerCase()
      : "";

  if (
    !email ||
    email.length > 254 ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  ) {
    return res.status(400).json({
      error: {
        code: "INVALID_EMAIL",
        message: "A valid registered user's email is required.",
      },
    });
  }

  try {
    const otherUser = await User.findOne({ email }).select("_id name email");

    if (!otherUser) {
      return res.status(404).json({
        error: {
          code: "USER_NOT_FOUND",
          message: "No registered user exists with this email.",
        },
      });
    }

    const currentUserId = req.auth.userId;
    const otherUserId = otherUser._id.toString();

    if (currentUserId === otherUserId) {
      return res.status(400).json({
        error: {
          code: "SELF_CONVERSATION_NOT_ALLOWED",
          message: "You cannot create a conversation with yourself.",
        },
      });
    }

    // Stable ID shared by both participants, independent of display names.
    const members = [currentUserId, otherUserId].sort();
    const conversationId = `dm_${members.join("_")}`;

    let conversation = await Conversation.findOne({ conversationId });

    if (!conversation) {
      try {
        conversation = await Conversation.create({
          conversationId,
          members,
        });
      } catch (error) {
        // Handle two simultaneous attempts to create the same conversation.
        if (error.code !== 11000) throw error;
        conversation = await Conversation.findOne({ conversationId });
      }
    }

    if (!conversation) {
      throw new Error("Conversation could not be created or retrieved.");
    }

    return res.status(200).json({
      conversation: {
        conversationId: conversation.conversationId,
        members: conversation.members,
      },
      otherUser: {
        id: otherUserId,
        name: otherUser.name,
        email: otherUser.email,
      },
    });
  } catch (error) {
    console.error("Conversation creation failed:", error.message);

    return res.status(500).json({
      error: {
        code: "CONVERSATION_CREATE_FAILED",
        message: "Unable to create or retrieve conversation.",
      },
    });
  }
});

/**
 * List conversations belonging to the authenticated user.
 * Includes the other participant and the latest message preview.
 */
app.get("/api/v1/conversations", requireAuth, async (req, res) => {
  try {
    const currentUserId = req.auth.userId;

    const conversations = await Conversation.find({
      members: currentUserId,
    }).lean();

    if (conversations.length === 0) {
      return res.status(200).json({ conversations: [] });
    }

    const conversationIds = conversations.map(
      (conversation) => conversation.conversationId,
    );

    const otherUserIds = [
      ...new Set(
        conversations.flatMap((conversation) =>
          conversation.members.filter(
            (memberId) => memberId !== currentUserId,
          ),
        ),
      ),
    ];

    const [users, messages] = await Promise.all([
      User.find({ _id: { $in: otherUserIds } })
        .select("_id name email")
        .lean(),

      Message.find({ conversationId: { $in: conversationIds } })
        .sort({ createdAt: -1 })
        .lean(),
    ]);

    const usersById = new Map(
      users.map((user) => [
        user._id.toString(),
        {
          id: user._id.toString(),
          name: user.name,
          email: user.email,
        },
      ]),
    );

    const latestMessageByConversation = new Map();

    for (const message of messages) {
      if (!latestMessageByConversation.has(message.conversationId)) {
        latestMessageByConversation.set(message.conversationId, {
          id: message._id.toString(),
          text: message.text,
          senderId: message.senderId,
          createdAt: message.createdAt.toISOString(),
        });
      }
    }

    const result = conversations
      .map((conversation) => {
        const otherUserId = conversation.members.find(
          (memberId) => memberId !== currentUserId,
        );

        return {
          conversationId: conversation.conversationId,
          otherUser: usersById.get(otherUserId) ?? null,
          lastMessage:
            latestMessageByConversation.get(
              conversation.conversationId,
            ) ?? null,
          updatedAt: conversation.updatedAt?.toISOString() ?? null,
        };
      })
      .sort((a, b) => {
        const timeA = a.lastMessage?.createdAt ?? a.updatedAt ?? "";
        const timeB = b.lastMessage?.createdAt ?? b.updatedAt ?? "";
        return timeB.localeCompare(timeA);
      });

    return res.status(200).json({ conversations: result });
  } catch (error) {
    console.error("Failed to fetch conversations:", error.message);

    return res.status(500).json({
      error: {
        code: "CONVERSATION_LIST_FAILED",
        message: "Unable to fetch conversations.",
      },
    });
  }
});



 // Fetch messages for one conversation.
app.get("/api/v1/messages", requireAuth, async (req, res) => {
  const conversationId =
    typeof req.query.conversationId === "string"
      ? req.query.conversationId.trim()
      : "";

  if (!conversationId || conversationId.length > 100) {
    return res.status(400).json({
      error: {
        code: "INVALID_CONVERSATION",
        message: "A valid conversationId is required.",
      },
    });
  }

  try {
    const conversation = await Conversation.findOne({
      conversationId,
      members: req.auth.userId,
    }).lean();

    if (!conversation) {
      return res.status(403).json({
        error: {
          code: "CONVERSATION_ACCESS_DENIED",
          message: "You are not a member of this conversation.",
        },
      });
    }

        const messages = await Message.find({ conversationId })
      .sort({ createdAt: 1 })
      .limit(100)
      .lean();

    const replyIds = [
      ...new Set(
        messages
          .map((message) => message.replyToMessageId)
          .filter(Boolean),
      ),
    ];

    const replyTargets = replyIds.length
      ? await Message.find({
          _id: { $in: replyIds },
          conversationId,
        }).lean()
      : [];

    const replyTargetMap = new Map(
      replyTargets.map((message) => [message._id.toString(), message]),
    );

    return res.status(200).json({
      messages: messages.map((message) => {
        const replyTarget = message.replyToMessageId
          ? replyTargetMap.get(message.replyToMessageId)
          : null;

        return {
          id: message._id.toString(),
          clientMessageId: message.clientMessageId ?? null,
          conversationId: message.conversationId,
          senderId: message.senderId,
          text: message.text,
          replyToMessageId: message.replyToMessageId ?? null,
          replyTo: replyTarget
            ? {
                id: replyTarget._id.toString(),
                senderId: replyTarget.senderId,
                text: replyTarget.text,
              }
            : null,
          createdAt: message.createdAt.toISOString(),
        };
      }),
    });
  } catch (error) {
    console.error("Failed to fetch messages:", error.message);

    return res.status(500).json({
      error: {
        code: "MESSAGE_FETCH_FAILED",
        message: "Unable to fetch messages.",
      },
    });
  }
});


// Save a message idempotently.
app.post("/api/v1/messages", requireAuth, async (req, res) => {
  const conversationId =
    typeof req.body?.conversationId === "string"
      ? req.body.conversationId.trim()
      : "";

  const clientMessageId =
    typeof req.body?.clientMessageId === "string"
      ? req.body.clientMessageId.trim()
      : "";

  const text =
    typeof req.body?.text === "string" ? req.body.text.trim() : "";

      const replyToMessageId =
      typeof req.body?.replyToMessageId === "string"
        ? req.body.replyToMessageId.trim()
        : null;

  const senderId = req.auth.userId;

  if (!conversationId || conversationId.length > 100) {
    return res.status(400).json({
      error: {
        code: "INVALID_CONVERSATION",
        message: "A valid conversationId is required.",
      },
    });
  }

  if (
    !clientMessageId ||
    clientMessageId.length > 100
  ) {
    return res.status(400).json({
      error: {
        code: "INVALID_CLIENT_MESSAGE_ID",
        message: "A valid clientMessageId is required.",
      },
    });
  }

  if (!text) {
    return res.status(400).json({
      error: {
        code: "INVALID_MESSAGE",
        message: "Message text is required.",
      },
    });
  }

  if (text.length > 4000) {
    return res.status(400).json({
      error: {
        code: "MESSAGE_TOO_LONG",
        message: "Message must not exceed 4000 characters.",
      },
    });
  }


  try {
    const conversation = await Conversation.findOne({
  conversationId,
  members: senderId,
}).lean();

if (!conversation) {
  return res.status(403).json({
    error: {
      code: "CONVERSATION_ACCESS_DENIED",
      message: "You are not a member of this conversation.",
    },
  });
}
          let replyToMessage = null;

      if (replyToMessageId) {
        if (replyToMessageId.length > 100) {
          return res.status(400).json({
            error: {
              code: "INVALID_REPLY_TARGET",
              message: "Invalid replyToMessageId.",
            },
          });
        }

        if (!mongoose.isValidObjectId(replyToMessageId)) {
          return res.status(400).json({
            error: {
              code: "INVALID_REPLY_TARGET",
              message: "Invalid reply target ID.",
            },
          });
        }

        replyToMessage = await Message.findOne({
          _id: replyToMessageId,
          conversationId,
        }).lean();

        if (!replyToMessage) {
          return res.status(400).json({
            error: {
              code: "INVALID_REPLY_TARGET",
              message: "Reply target was not found in this conversation.",
            },
          });
        }
      }
    const existing = await Message.findOne({
      conversationId,
      senderId,
      clientMessageId,
    });

    if (existing) {
      if (
  existing.text !== text ||
  (existing.replyToMessageId ?? null) !==
    (replyToMessage ? replyToMessage._id.toString() : null)
) {
        return res.status(409).json({
          error: {
            code: "IDEMPOTENCY_CONFLICT",
            message:
              "This clientMessageId was already used for different content.",
          },
        });
      }

      return res.status(200).json({
        message: serializeMessage(existing),
        deduplicated: true,
      });
    }

    const message = await Message.create({
  clientMessageId,
  conversationId,
  senderId,
  text,
  replyToMessageId: replyToMessage ? replyToMessage._id.toString() : null,
});

const serializedMessage = serializeMessage(message, replyToMessage);

// Broadcast only after the database save succeeds.
req.app
  .get("io")
  ?.to(`conversation:${conversationId}`)
  .emit("message:new", serializedMessage);

return res.status(201).json({
  message: serializedMessage,
  deduplicated: false,
});
  } catch (error) {
    // If concurrent requests race, a unique database index should
    // allow one insert. Re-read the winner when the index exists.
    if (error.code === 11000) {
      const existing = await Message.findOne({
        conversationId,
        senderId,
        clientMessageId,
      });

      if (existing && existing.text === text) {
        return res.status(200).json({
          message: serializeMessage(existing, replyToMessage),
          deduplicated: true,
        });
      }

      if (existing) {
        return res.status(409).json({
          error: {
            code: "IDEMPOTENCY_CONFLICT",
            message:
              "This clientMessageId was already used for different content.",
          },
        });
      }
    }

    console.error("Failed to save message:", error.message);

    return res.status(500).json({
      error: {
        code: "MESSAGE_SAVE_FAILED",
        message: "Unable to save message.",
      },
    });
  }
});

app.use((_req, res) => {
  res.status(404).json({
    error: {
      code: "NOT_FOUND",
      message: "Route not found",
    },
  });
});

export default app;
