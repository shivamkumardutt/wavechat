
import dns from "node:dns";
dns.setServers(["1.1.1.1", "8.8.8.8"]);
import "dotenv/config";
import app from "./app.js";
import { connectDB } from "./connectDB.js";

const port = Number(process.env.PORT) || 3000;
const host = process.env.HOST || "0.0.0.0";

async function startServer() {
  try {
    await connectDB();

    const server = app.listen(port, host, () => {
      console.log(`WaveChat API listening on ${host}:${port}`);
    });

    function shutdown() {
      server.close(() => process.exit(0));
    }

    process.once("SIGINT", shutdown);
    process.once("SIGTERM", shutdown);
  } catch (error) {
    console.error("Failed to start WaveChat API:", error.message);
    process.exit(1);
  }
}

startServer();
