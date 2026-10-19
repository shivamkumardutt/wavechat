
import { test } from "node:test";
import assert from "node:assert/strict";
import express from "express";
import request from "supertest";
import jwt from "jsonwebtoken";
import { requireAuth } from "../src/middleware/auth.js";

const secret = "wavechat-test-secret-at-least-32-characters-long";
process.env.JWT_SECRET = secret;

const app = express();

app.get("/protected", requireAuth, (req, res) => {
  res.status(200).json({ userId: req.auth.userId });
});

test("protected route rejects a missing token", async () => {
  const response = await request(app)
    .get("/protected")
    .expect(401);

  assert.equal(response.body.error.code, "AUTH_REQUIRED");
});

test("protected route rejects an invalid token", async () => {
  const response = await request(app)
    .get("/protected")
    .set("Authorization", "Bearer invalid-token")
    .expect(401);

  assert.equal(response.body.error.code, "INVALID_TOKEN");
});

test("protected route accepts a valid token", async () => {
  const token = jwt.sign(
    { sub: "test-user-123" },
    secret,
    {
      expiresIn: "1h",
      issuer: "wavechat-api",
      audience: "wavechat-app",
    },
  );

  const response = await request(app)
    .get("/protected")
    .set("Authorization", `Bearer ${token}`)
    .expect(200);

  assert.equal(response.body.userId, "test-user-123");
});

test("protected route rejects an expired token", async () => {
  const token = jwt.sign(
    { sub: "test-user-123" },
    secret,
    {
      expiresIn: -1,
      issuer: "wavechat-api",
      audience: "wavechat-app",
    },
  );

  const response = await request(app)
    .get("/protected")
    .set("Authorization", `Bearer ${token}`)
    .expect(401);

  assert.equal(response.body.error.code, "INVALID_TOKEN");
});
