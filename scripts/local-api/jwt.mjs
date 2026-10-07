// Maakt lokale test-JWT's (HS256) voor de PostgREST-teststack. NIET voor productie.
import { createHmac } from "node:crypto";
const SECRET = process.env.LOCAL_JWT_SECRET ?? "local-only-secret-at-least-32-characters!!";
const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
export function sign(payload) {
  const head = b64({ alg: "HS256", typ: "JWT" });
  const body = b64({ iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 3600 * 24 * 365, ...payload });
  const sig = createHmac("sha256", SECRET).update(`${head}.${body}`).digest("base64url");
  return `${head}.${body}.${sig}`;
}
if (process.argv[2]) console.log(sign(JSON.parse(process.argv[2])));
