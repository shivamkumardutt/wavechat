import "dotenv/config";
import app from "./app.js";

const port = Number(process.env.PORT) || 3000;

const server = app.listen(port, () => {
  console.log(`WaveChat API listening on port ${port}`);
});

function shutdown() {
  server.close(() => process.exit(0));
}

process.once("SIGINT", shutdown);
process.once("SIGTERM", shutdown);
