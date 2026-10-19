
import { before, after, test } from "node:test";
import assert from "node:assert/strict";
import request from "supertest";
import mongoose from "mongoose";
import bcrypt from "bcryptjs";
import { MongoMemoryServer } from "mongodb-memory-server";
import app from "../src/app.js";
import User from "../src/models/User.js";
process.env.JWT_SECRET = "wavechat-test-secret-at-least-32-characters-long";

let mongoServer;

before(async () => {
  mongoServer = await MongoMemoryServer.create();
  await mongoose.connect(mongoServer.getUri());
});

after(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

test("registration creates a user without returning the password hash", async () => {
  const response = await request(app)
    .post("/api/v1/auth/register")
    .send({
      name: "Test User",
      email: "test@example.com",
      password: "securePassword123",
    });

  assert.equal(response.status, 201);
  assert.equal(response.body.user.name, "Test User");
  assert.equal(response.body.user.email, "test@example.com");
  assert.ok(response.body.user.id);
  assert.equal(response.body.user.passwordHash, undefined);

  const user = await User.findOne({
    email: "test@example.com",
  }).select("+passwordHash");

  assert.ok(user);
  assert.notEqual(user.passwordHash, "securePassword123");
  assert.equal(
    await bcrypt.compare("securePassword123", user.passwordHash),
    true,
  );
});

test("registration rejects an invalid email", async () => {
  const response = await request(app)
    .post("/api/v1/auth/register")
    .send({
      name: "Test User",
      email: "not-an-email",
      password: "securePassword123",
    });

  assert.equal(response.status, 400);
  assert.equal(response.body.error.code, "INVALID_EMAIL");
});

test("registration rejects a short password", async () => {
  const response = await request(app)
    .post("/api/v1/auth/register")
    .send({
      name: "Test User",
      email: "short-password@example.com",
      password: "123",
    });

  assert.equal(response.status, 400);
  assert.equal(response.body.error.code, "INVALID_PASSWORD");
});

test("registration rejects duplicate email addresses", async () => {
  const payload = {
    name: "Test User",
    email: "duplicate@example.com",
    password: "securePassword123",
  };

  const firstResponse = await request(app)
    .post("/api/v1/auth/register")
    .send(payload);

  assert.equal(firstResponse.status, 201);

  const secondResponse = await request(app)
    .post("/api/v1/auth/register")
    .send(payload);

  assert.equal(secondResponse.status, 409);
  assert.equal(
    secondResponse.body.error.code,
    "EMAIL_ALREADY_REGISTERED",
  );
});

test("login returns a JWT for valid credentials", async () => {
  await request(app)
    .post("/api/v1/auth/register")
    .send({
      name: "Login Test",
      email: "login-test@example.com",
      password: "securePassword123",
    })
    .expect(201);

  const response = await request(app)
    .post("/api/v1/auth/login")
    .send({
      email: "login-test@example.com",
      password: "securePassword123",
    })
    .expect(200);

  assert.equal(typeof response.body.token, "string");
  assert.ok(response.body.token.length > 0);
  assert.equal(response.body.tokenType, "Bearer");
  assert.equal(response.body.user.email, "login-test@example.com");
});

test("login rejects an incorrect password", async () => {
  await request(app)
    .post("/api/v1/auth/register")
    .send({
      name: "Wrong Password Test",
      email: "wrong-password@example.com",
      password: "securePassword123",
    })
    .expect(201);

  const response = await request(app)
    .post("/api/v1/auth/login")
    .send({
      email: "wrong-password@example.com",
      password: "incorrectPassword123",
    })
    .expect(401);

  assert.equal(response.body.error.code, "INVALID_CREDENTIALS");
});

test("login rejects missing credentials", async () => {
  const response = await request(app)
    .post("/api/v1/auth/login")
    .send({
      email: "login-test@example.com",
    })
    .expect(400);

  assert.equal(response.body.error.code, "MISSING_CREDENTIALS");
});

import jwt from "jsonwebtoken";
import { requireAuth } from "../src/middleware/auth.js";

test("protected middleware rejects a missing token", async () => {
  const response = await request(app)
    .get("/api/v1/protected-test")
    .expect(404);

  assert.equal(response.status, 404);
});
