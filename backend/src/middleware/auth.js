
import jwt from "jsonwebtoken";

export function requireAuth(req, res, next) {
  const authorization = req.headers.authorization;

  if (
    typeof authorization !== "string" ||
    !authorization.startsWith("Bearer ")
  ) {
    return res.status(401).json({
      error: {
        code: "AUTH_REQUIRED",
        message: "A valid Bearer token is required.",
      },
    });
  }

  const token = authorization.slice("Bearer ".length).trim();
  const secret = process.env.JWT_SECRET;

  if (!token || !secret || secret.length < 32) {
    return res.status(401).json({
      error: {
        code: "INVALID_TOKEN",
        message: "Authentication token is invalid.",
      },
    });
  }

  try {
    const payload = jwt.verify(token, secret, {
      issuer: "wavechat-api",
      audience: "wavechat-app",
    });

    if (typeof payload.sub !== "string" || !payload.sub) {
      return res.status(401).json({
        error: {
          code: "INVALID_TOKEN",
          message: "Authentication token is invalid.",
        },
      });
    }

    req.auth = { userId: payload.sub };
    return next();
  } catch {
    return res.status(401).json({
      error: {
        code: "INVALID_TOKEN",
        message: "Authentication token is invalid or expired.",
      },
    });
  }
}
