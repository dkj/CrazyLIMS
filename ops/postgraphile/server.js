const express = require("express");
const { postgraphile } = require("postgraphile");
const jwt = require("jsonwebtoken");

const connectionString =
  process.env.POSTGRAPHILE_DB_URI ||
  process.env.DATABASE_URL ||
  "postgres://postgraphile_authenticator:postgraphilepass@db:5432/lims";

const schemaList = (process.env.POSTGRAPHILE_SCHEMAS || "lims,public")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

const fallbackRole = process.env.POSTGRAPHILE_DEFAULT_ROLE || "web_anon";
const jwtSecret = process.env.POSTGRAPHILE_JWT_SECRET || process.env.PGRST_JWT_SECRET || null;
const jwtAudience = process.env.POSTGRAPHILE_JWT_AUD || undefined;
const jwtIssuer = process.env.POSTGRAPHILE_JWT_ISS || undefined;
const enableWatch =
  (process.env.POSTGRAPHILE_WATCH || "true").toLowerCase() !== "false";
const port = Number(process.env.POSTGRAPHILE_PORT || 3001);

const app = express();

function normalizeRoles(claims) {
  if (!claims) return [];
  if (Array.isArray(claims.roles)) {
    return claims.roles.map((role) => String(role).toLowerCase());
  }
  if (claims.role) {
    return [String(claims.role).toLowerCase()];
  }
  return [];
}

app.use((req, res, next) => {
  if (!jwtSecret) {
    return next();
  }

  const authHeader = req.headers.authorization || req.headers.Authorization;
  if (!authHeader) {
    return next();
  }

  const parts = authHeader.split(" ");
  if (parts.length !== 2 || parts[0].toLowerCase() !== "bearer") {
    return res.status(401).json({ errors: [{ message: "Invalid authorization header" }] });
  }

  const token = parts[1];
  try {
    const verifyOptions = {};
    if (jwtAudience) {
      verifyOptions.audience = jwtAudience;
    }
    if (jwtIssuer) {
      verifyOptions.issuer = jwtIssuer;
    }
    req.jwtClaims = jwt.verify(token, jwtSecret, verifyOptions);
  } catch (error) {
    return res.status(401).json({ errors: [{ message: "Invalid JWT" }] });
  }

  return next();
});

app.use(
  postgraphile(connectionString, schemaList, {
    watchPg: enableWatch,
    graphiql: true,
    enhanceGraphiql: true,
    dynamicJson: true,
    pgSettings: async (req) => {
      const settings = {
        role: fallbackRole,
      };

      const claims = req && req.jwtClaims ? req.jwtClaims : null;

      if (claims) {
        settings["request.jwt.claims"] = JSON.stringify(claims);

        const roles = normalizeRoles(claims);
        if (roles.length > 0) {
          settings["lims.current_roles"] = roles.join(",");
          settings.role = roles[0];
        }

        if (claims.user_id) {
          settings["lims.current_user_id"] = String(claims.user_id);
        }
      }

      return settings;
    },
  })
);

app.listen(port, "0.0.0.0", () => {
  // eslint-disable-next-line no-console
  console.log(`PostGraphile listening on http://0.0.0.0:${port}`);
});
