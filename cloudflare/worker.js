export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // Shared CORS headers: completely public, no auth required for reads.
    const CORS_HEADERS = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type,Authorization",
    };

    // Handle preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: CORS_HEADERS });
    }

    // Only respond on / and /cop, 404 otherwise
    if (url.pathname !== "/" && url.pathname !== "/cop") {
      return new Response("Not found", {
        status: 404,
        headers: CORS_HEADERS,
      });
    }

    // GET: return current value (or empty string if unset) — no auth required
    if (request.method === "GET") {
      const value = (await env.COP_STORE.get("cop_value")) ?? "";
      return new Response(value, { headers: CORS_HEADERS });
    }

    // POST: require Bearer token matching COP_WRITE_SECRET
    if (request.method === "POST") {
      const authHeader = request.headers.get("Authorization") ?? "";
      const token = authHeader.startsWith("Bearer ")
        ? authHeader.slice(7)
        : "";

      if (!env.COP_WRITE_SECRET || token !== env.COP_WRITE_SECRET) {
        return new Response("Unauthorized", {
          status: 401,
          headers: CORS_HEADERS,
        });
      }

      const text = await request.text();
      await env.COP_STORE.put("cop_value", text);
      return new Response("ok", { headers: CORS_HEADERS });
    }

    // Anything else: 405
    return new Response("Method not allowed", {
      status: 405,
      headers: CORS_HEADERS,
    });
  },
};
