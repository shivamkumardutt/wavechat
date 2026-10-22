import { Server } from "socket.io";
import jwt from "jsonwebtoken";
import Conversation from "./models/Conversation.js";

export function attachRealtime(server, app) {
  const io = new Server(server, {
    cors: {
      origin: process.env.CORS_ORIGIN
        ? process.env.CORS_ORIGIN.split(",").map((value) => value.trim())
        : false,
      methods: ["GET", "POST"],
    },
    maxHttpBufferSize: 64 * 1024,
  });

  // Authenticate every socket connection with the same JWT rules as REST.
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token;
    const secret = process.env.JWT_SECRET;

    if (
      typeof token !== "string" ||
      !token ||
      !secret ||
      secret.length < 32
    ) {
      return next(new Error("Authentication required"));
    }

    try {
      const payload = jwt.verify(token, secret, {
        issuer: "wavechat-api",
        audience: "wavechat-app",
      });

      if (typeof payload.sub !== "string" || !payload.sub) {
        return next(new Error("Invalid authentication token"));
      }

      socket.data.userId = payload.sub;
      return next();
    } catch {
      return next(new Error("Invalid or expired authentication token"));
    }
  });

  io.on("connection", (socket) => {
    console.log(`[Socket.IO] Authenticated connection: ${socket.data.userId}`);

    socket.on("conversation:join", async (payload, acknowledge) => {
      const reply = typeof acknowledge === "function"
        ? acknowledge
        : () => {};

      const conversationId =
        typeof payload?.conversationId === "string"
          ? payload.conversationId.trim()
          : "";

      if (!conversationId || conversationId.length > 100) {
        return reply({
          ok: false,
          error: "INVALID_CONVERSATION",
        });
      }

      try {
        const conversation = await Conversation.findOne({
          conversationId,
          members: socket.data.userId,
        }).lean();

        if (!conversation) {
          return reply({
            ok: false,
            error: "CONVERSATION_ACCESS_DENIED",
          });
        }

        await socket.join(`conversation:${conversationId}`);

        return reply({
          ok: true,
          conversationId,
        });
      } catch (error) {
        console.error("[Socket.IO] Conversation join failed:", error.message);

        return reply({
          ok: false,
          error: "INTERNAL_ERROR",
        });
      }
    });

    socket.on("conversation:leave", async (payload) => {
      const conversationId =
        typeof payload?.conversationId === "string"
          ? payload.conversationId.trim()
          : "";

      if (conversationId && conversationId.length <= 100) {
        await socket.leave(`conversation:${conversationId}`);
      }
    });

    socket.on("disconnect", (reason) => {
      console.log(`[Socket.IO] Disconnected: ${reason}`);
    });
  });

  app.set("io", io);
  return io;
}