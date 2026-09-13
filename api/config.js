const escapeJs = (value) => String(value ?? '')
  .replace(/\\/g, '\\\\')
  .replace(/'/g, "\\'")
  .replace(/\r/g, '\\r')
  .replace(/\n/g, '\\n');

module.exports = function handler(req, res) {
  if (req.method !== 'GET') {
    res.statusCode = 405;
    res.setHeader('Allow', 'GET');
    return res.end('Method Not Allowed');
  }

  const url = process.env.SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY;

  if (!url || !anonKey) {
    res.statusCode = 500;
    res.setHeader('Content-Type', 'application/javascript; charset=utf-8');
    return res.end("window.SUPABASE_CONFIG_ERROR='Supabase environment variables are missing on Vercel.';");
  }

  res.setHeader('Content-Type', 'application/javascript; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store, max-age=0');
  return res.end(
    `window.SUPABASE_CONFIG={url:'${escapeJs(url)}',anonKey:'${escapeJs(anonKey)}'};`
  );
};
