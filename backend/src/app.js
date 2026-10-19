import express from "express";
import helmet from "helmet";
import cors from "cors";

const app = express();

app.use(helmet());

app.use(cors({
  origin: process.env.CORS_ORIGIN
    ? process.env.CORS_ORIGIN.split(",").map(value => value.trim())
    : false,
}));

app.use(express.json({ limit: "1mb" }));

app.get("/api/v1/health", (_req, res) => {
  res.status(200).json({
    status: "ok",
    service: "wavechat-api",
  });
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
