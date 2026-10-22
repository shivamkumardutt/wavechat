import dns from "node:dns";
import "dotenv/config";
import { createServer } from "node:http";
import app from "./app.js";
import { connectDB } from "./connectDB.js";
import { attachRealtime } from "./realtime.js";

dns.setServers(["1.1.1.1", "8.8.8.8"]);

const port = Number(process.env.PORT) || 3000;
const host = process.env.HOST || "0.0.0.0";

async function startServer() {
  try {
    await connectDB();

    const server = createServer(app);
    const io = attachRealtime(server, app);

    server.listen(port, host, () => {
      console.log(`WaveChat API listening on ${host}:${port}`);
      console.log("WaveChat Socket.IO initialized");
    });

    function shutdown() {
      io.close(() => process.exit(0));
    }

    process.once("SIGINT", shutdown);
    process.once("SIGTERM", shutdown);
  } catch (error) {
    console.error("Failed to start WaveChat API:", error.message);
    process.exit(1);
  }
}

startServer();