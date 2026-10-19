import { before, after, afterEach, test } from "node:test";
import assert from "node:assert/strict";
import request from "supertest";
import mongoose from "mongoose";
import jwt from "jsonwebtoken";
import { MongoMemoryServer } from "mongodb-memory-server";

import app from "../src/app.js";
import Conversation from "../src/models/Conversation.js";
import Message from "../src/models/Message.js";

const TEST_JWT_SECRET =
  "wavechat-test-secret-at-least-32-characters-long";

process.env.JWT_SECRET = TEST_JWT_SECRET;

function createToken(userId = "test-user") {
  return jwt.sign(
    { sub: userId },
    TEST_JWT_SECRET,
    {
      expiresIn: "1h",
      issuer: "wavechat-api",
      audience: "wavechat-app",
    },
  );
}

function authenticatedRequest(requestBuilder, userId = "test-user") {
  return requestBuilder.set(
    "Authorization",
    `Bearer ${createToken(userId)}`,
  );
}

async function createConversation(
  conversationId,
  members = ["test-user"],
) {
  return Conversation.create({
    conversationId,
    members,
  });
}

let mongoServer;

before(async () => {
  mongoServer = await MongoMemoryServer.create();
  await mongoose.connect(mongoServer.getUri());
});

afterEach(async () => {
  await Message.deleteMany({});
  await Conversation.deleteMany({});
});

after(async () => {
  await mongoose.disconnect();

  if (mongoServer) {
    await mongoServer.stop();
  }
});

test("GET messages rejects a missing token", async () => {
  const response = await request(app)
    .get("/api/v1/messages")
    .query({ conversationId: "conversation-1" });

  assert.equal(response.status, 401);
  assert.equal(response.body.error.code, "AUTH_REQUIRED");
});

test("POST messages rejects an invalid token", async () => {
  const response = await request(app)
    .post("/api/v1/messages")
    .set("Authorization", "Bearer invalid-token")
    .send({
      conversationId: "conversation-1",
      clientMessageId: "invalid-token-test",
      text: "Should not be saved",
    });

  assert.equal(response.status, 401);
  assert.equal(response.body.error.code, "INVALID_TOKEN");
});

test("POST creates a message and GET retrieves it for its conversation", async () => {
  await createConversation("conversation-1");

  const response = await authenticatedRequest(
    request(app).post("/api/v1/messages"),
  ).send({
    conversationId: "conversation-1",
    clientMessageId: "test-message-1",
    text: "Automated test message",
    senderId: "untrusted-sender",
  });

  assert.equal(response.status, 201);
  assert.equal(response.body.message.conversationId, "conversation-1");
  assert.equal(response.body.message.clientMessageId, "test-message-1");
  assert.equal(response.body.message.text, "Automated test message");
  assert.equal(response.body.message.senderId, "test-user");

  const listResponse = await authenticatedRequest(
    request(app).get("/api/v1/messages"),
  ).query({ conversationId: "conversation-1" });

  assert.equal(listResponse.status, 200);

  assert.ok(
    listResponse.body.messages.some(
      (message) => message.id === response.body.message.id,
    ),
  );
});

test("GET does not return messages from another conversation", async () => {
  await createConversation("conversation-A");
  await createConversation("conversation-B");

  const createResponse = await authenticatedRequest(
    request(app).post("/api/v1/messages"),
  ).send({
    conversationId: "conversation-A",
    clientMessageId: "test-message-A",
    text: "Private conversation A",
  });

  assert.equal(createResponse.status, 201);

  const response = await authenticatedRequest(
    request(app).get("/api/v1/messages"),
  ).query({ conversationId: "conversation-B" });

  assert.equal(response.status, 200);
  assert.equal(response.body.messages.length, 0);
});

test("POST rejects a missing conversationId", async () => {
  const response = await authenticatedRequest(
    request(app).post("/api/v1/messages"),
  ).send({
    clientMessageId: "missing-conversation-test",
    text: "Missing conversation",
  });

  assert.equal(response.status, 400);
  assert.equal(response.body.error.code, "INVALID_CONVERSATION");
});

test("GET rejects a missing conversationId", async () => {
  const response = await authenticatedRequest(
    request(app).get("/api/v1/messages"),
  );

  assert.equal(response.status, 400);
  assert.equal(response.body.error.code, "INVALID_CONVERSATION");
});

test("POST rejects an empty message", async () => {
  const response = await authenticatedRequest(
    request(app).post("/api/v1/messages"),
  ).send({
    conversationId: "conversation-1",
    clientMessageId: "empty-message-test",
    text: "   ",
  });

  assert.equal(response.status, 400);
  assert.equal(response.body.error.code, "INVALID_MESSAGE");
});

test("POST rejects messages longer than 4000 characters", async () => {
  const response = await authenticatedRequest(
    request(app).post("/api/v1/messages"),
  ).send({
    conversationId: "conversation-1",
    clientMessageId: "long-message-test",
    text: "a".repeat(4001),
  });

  assert.equal(response.status, 400);
  assert.equal(response.body.error.code, "MESSAGE_TOO_LONG");
});

test("POST does not create duplicate messages for the same clientMessageId", async () => {
  await createConversation("conversation-idempotency");

  const payload = {
    conversationId: "conversation-idempotency",
    clientMessageId: "retry-message-1",
    text: "Send this only once",
  };

  const first = await authenticatedRequest(
    request(app).post("/api/v1/messages"),
  ).send(payload);

  const second = await authenticatedRequest(
    request(app).post("/api/v1/messages"),
  ).send(payload);

  assert.equal(first.status, 201);
  assert.equal(second.status, 200);
  assert.equal(second.body.deduplicated, true);
  assert.equal(second.body.message.id, first.body.message.id);

  const list = await authenticatedRequest(
    request(app).get("/api/v1/messages"),
  ).query({ conversationId: "conversation-idempotency" });

  assert.equal(list.status, 200);
  assert.equal(list.body.messages.length, 1);
});

test("POST rejects reusing a clientMessageId with different content", async () => {
  await createConversation("conversation-conflict");

  const first = await authenticatedRequest(
    request(app).post("/api/v1/messages"),
  ).send({
    conversationId: "conversation-conflict",
    clientMessageId: "conflict-message-1",
    text: "Original message",
  });

  const second = await authenticatedRequest(
    request(app).post("/api/v1/messages"),
  ).send({
    conversationId: "conversation-conflict",
    clientMessageId: "conflict-message-1",
    text: "Different message",
  });

  assert.equal(first.status, 201);
  assert.equal(second.status, 409);
  assert.equal(second.body.error.code, "IDEMPOTENCY_CONFLICT");
});

test("non-members cannot read or send messages in a conversation", async () => {
  await createConversation(
    "private-conversation",
    ["owner-user"],
  );

  const readResponse = await authenticatedRequest(
    request(app).get("/api/v1/messages"),
    "outsider-user",
  ).query({
    conversationId: "private-conversation",
  });

  assert.equal(readResponse.status, 403);
  assert.equal(
    readResponse.body.error.code,
    "CONVERSATION_ACCESS_DENIED",
  );

  const sendResponse = await authenticatedRequest(
    request(app).post("/api/v1/messages"),
    "outsider-user",
  ).send({
    conversationId: "private-conversation",
    clientMessageId: "outsider-message",
    text: "Should not be saved",
  });

  assert.equal(sendResponse.status, 403);
  assert.equal(
    sendResponse.body.error.code,
    "CONVERSATION_ACCESS_DENIED",
  );

  const savedMessage = await Message.findOne({
    conversationId: "private-conversation",
    clientMessageId: "outsider-message",
  });

  assert.equal(savedMessage, null);
});

test("a conversation member can read and send messages", async () => {
  await createConversation(
    "members-conversation",
    ["owner-user", "member-user"],
  );

  const sendResponse = await authenticatedRequest(
    request(app).post("/api/v1/messages"),
    "member-user",
  ).send({
    conversationId: "members-conversation",
    clientMessageId: "member-message-1",
    text: "Hello from a member",
  });

  assert.equal(sendResponse.status, 201);
  assert.equal(sendResponse.body.message.senderId, "member-user");

  const readResponse = await authenticatedRequest(
    request(app).get("/api/v1/messages"),
    "member-user",
  ).query({
    conversationId: "members-conversation",
  });

  assert.equal(readResponse.status, 200);
  assert.equal(readResponse.body.messages.length, 1);
  assert.equal(
    readResponse.body.messages[0].text,
    "Hello from a member",
  );
});