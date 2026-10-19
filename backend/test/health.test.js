import { test } from "node:test";
import assert from "node:assert/strict";
import request from "supertest";
import app from "../src/app.js";

test("health endpoint returns 200", async () => {
  const response = await request(app)
    .get("/api/v1/health")
    .expect("Content-Type", /json/)
    .expect(200);

  assert.deepEqual(response.body, {
    status: "ok",
    service: "wavechat-api",
  });
});

test("unknown routes return 404", async () => {
  const response = await request(app)
    .get("/route-that-does-not-exist")
    .expect(404);

  assert.equal(response.body.error.code, "NOT_FOUND");
});
