// Mini "Supabase"-gateway voor lokaal testen: /rest/v1/* → PostgREST.
import http from "node:http";
const UPSTREAM = { host: "127.0.0.1", port: Number(process.env.PGRST_PORT ?? 3002) };
const PORT = Number(process.env.PORT ?? 54321);
http
  .createServer((req, res) => {
    if (!req.url.startsWith("/rest/v1")) {
      res.writeHead(404).end("alleen /rest/v1 in de lokale stack");
      return;
    }
    const headers = { ...req.headers };
    // supabase-js stuurt de anon key als apikey; PostgREST wil een Bearer-token
    if (!headers.authorization && headers.apikey) headers.authorization = `Bearer ${headers.apikey}`;
    const up = http.request(
      { ...UPSTREAM, method: req.method, path: req.url.replace(/^\/rest\/v1/, "") || "/", headers },
      (r) => {
        res.writeHead(r.statusCode ?? 502, r.headers);
        r.pipe(res);
      },
    );
    up.on("error", (e) => res.writeHead(502).end(String(e)));
    req.pipe(up);
  })
  .listen(PORT, () => console.log(`lokale API op http://127.0.0.1:${PORT}/rest/v1`));
