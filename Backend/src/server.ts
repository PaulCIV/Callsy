import app from "./app";
import { env } from "./config/env";
import { connectDb } from "./config/db";

async function start() {
  try {
    await connectDb();

    app.listen(env.PORT, () => {
      console.log(`🚀 Server running on http://localhost:${env.PORT}`);
    });
  } catch (err) {
    console.error("❌ Failed to start server:", err);
    process.exit(1);
  }
}

start();