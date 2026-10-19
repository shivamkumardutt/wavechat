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


function serializeMessage(message) {
  return {
    id: message._id.toString(),
    clientMessageId: message.clientMessageId,
    conversationId: message.conversationId,
    senderId: message.senderId,
    text: message.text,
    createdAt: message.createdAt.toISOString(),
  };
}


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

    return res.status(200).json({
      messages: messages.map((message) => ({
        id: message._id.toString(),
        clientMessageId: message.clientMessageId ?? null,
        conversationId: message.conversationId,
        senderId: message.senderId,
        text: message.text,
        createdAt: message.createdAt.toISOString(),
      })),
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
    const existing = await Message.findOne({
      conversationId,
      senderId,
      clientMessageId,
    });

    if (existing) {
      if (existing.text !== text) {
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
    });

    return res.status(201).json({
      message: serializeMessage(message),
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
          message: serializeMessage(existing),
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
