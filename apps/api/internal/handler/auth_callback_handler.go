package handler

import (
	"html/template"
	"net/http"
)

// AuthCallbackHandler serves GET /auth/callback — the page every Supabase Auth
// email link lands on when it cannot go straight to the app.
//
// GoTrue redirects to `redirect_to` after verifying a link, and falls back to
// the project's Site URL whenever `redirect_to` is missing or not allow-listed.
// A recovery email triggered from the Supabase dashboard carries no
// `redirect_to` at all, so it always takes that fallback. Site URL used to
// point at /support, which meant the one thing the recipient needed — a way to
// set a new password — was nowhere on the page they were sent to, while the
// recovery token sat unused in the URL fragment.
//
// This page is that fallback: it forwards the whole query string *and*
// fragment to `navis://login-callback`, which is what the app already listens
// on, and explains itself when the scheme cannot be handled (a desktop
// browser, or a phone without Navis). It never inspects the token — the
// forwarding happens client-side, so nothing sensitive reaches the server.
type AuthCallbackHandler struct {
	stores StoreLinks
}

// NewAuthCallbackHandler creates an AuthCallbackHandler.
func NewAuthCallbackHandler(stores StoreLinks) *AuthCallbackHandler {
	return &AuthCallbackHandler{stores: stores}
}

// Callback handles GET /auth/callback.
func (h *AuthCallbackHandler) Callback(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	// The URL carries a single-use auth token. Keep it out of every cache, out
	// of search engines, and out of the Referer header of any onward request.
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Referrer-Policy", "no-referrer")
	w.Header().Set("X-Robots-Tag", "noindex, nofollow")
	_ = authCallbackTemplate.Execute(w, map[string]any{
		"IOSStore":     h.stores.IOS,
		"AndroidStore": h.stores.Android,
		"HasStore":     h.stores.IOS != "" || h.stores.Android != "",
	})
}

// The page decides client-side because the interesting half of a GoTrue
// redirect lives in the fragment, which the server never sees: the implicit
// flow returns `#access_token=…&type=recovery` and an exhausted or expired
// link returns `#error=access_denied&error_code=otp_expired`. Everything is
// inline — the public pages ship under a strict CSP with no external origins.
var authCallbackTemplate = template.Must(template.New("authCallback").Parse(`<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>Continuar en Navis</title>
<style>
  :root { --navy:#1B2A4A; --cyan:#4DA8DA; --amber:#F39C12; --muted:#9fb3d1; }
  * { box-sizing:border-box; margin:0; padding:0; }
  body { font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
         background:var(--navy); color:#fff; min-height:100vh;
         display:flex; align-items:center; justify-content:center; padding:24px; }
  .card { width:100%; max-width:420px; text-align:center; }
  .mark { font-size:44px; line-height:1; margin-bottom:14px; }
  h1 { font-size:24px; font-weight:700; margin-bottom:8px; }
  p { color:var(--muted); font-size:15px; line-height:1.55; }
  a.btn { display:block; text-decoration:none; font-weight:700; padding:15px;
          border-radius:14px; margin-top:14px; }
  a.primary { background:var(--cyan); color:#06203a; }
  a.secondary { background:rgba(255,255,255,.08); color:#fff;
                border:1px solid rgba(255,255,255,.18); }
  .hint { margin-top:18px; font-size:13px; color:var(--muted); }
  .warn { color:var(--amber); }
  [hidden] { display:none !important; }
</style>
</head>
<body>
<div class="card">
  <div class="mark">⚓</div>

  <div id="ok" hidden>
    <h1>Continúa en Navis</h1>
    <p>Estamos abriendo la app para que termines. Si no se abre sola, toca el botón.</p>
    <a class="btn primary" id="open" href="#">Abrir en Navis</a>
    <p class="hint">Este enlace solo funciona en el móvil donde tienes Navis instalada, y solo una vez.</p>
  </div>

  <div id="expired" hidden>
    <h1 class="warn">El enlace ya no vale</h1>
    <p>Los enlaces caducan al cabo de una hora y solo se pueden usar una vez. Vuelve a Navis y pide uno nuevo desde &laquo;Olvidaste tu contraseña&raquo;.</p>
  </div>

  <div id="plain" hidden>
    <h1>Abre Navis</h1>
    <p>Esta página es el punto de aterrizaje de los enlaces que Navis te envía por correo. Si has llegado aquí a mano, no hay nada que hacer: abre la app directamente.</p>
  </div>

  {{if .HasStore}}
    {{if .IOSStore}}<a class="btn secondary" href="{{.IOSStore}}">Descargar para iPhone</a>{{end}}
    {{if .AndroidStore}}<a class="btn secondary" href="{{.AndroidStore}}">Descargar para Android</a>{{end}}
  {{end}}
  <p class="hint">Navis &middot; cuaderno de bitácora y mantenimiento de tu barco</p>
</div>
<script>
  (function () {
    var search = window.location.search || '';
    var rawHash = window.location.hash || '';
    var hash = rawHash.charAt(0) === '#' ? rawHash.substring(1) : rawHash;

    // GoTrue puts its payload in the fragment (implicit flow, and every error)
    // or in the query string (PKCE returns ?code=). Read both.
    var fields = new URLSearchParams(hash);
    var query = new URLSearchParams(search.substring(1));
    function get(name) { return fields.get(name) || query.get(name); }

    var failed = get('error') || get('error_code');
    var token = get('access_token') || get('code') || get('token_hash');

    function show(id) { document.getElementById(id).hidden = false; }

    if (failed) { show('expired'); return; }
    if (!token) { show('plain'); return; }

    // Hand the app exactly what we were given, untouched: the app is the only
    // side that can finish the exchange (the PKCE verifier never leaves it).
    var link = document.getElementById('open');
    link.setAttribute('href', 'navis://login-callback' + search + rawHash);
    show('ok');

    // A tick after paint, so the page is already behind the "open in app?"
    // prompt rather than appearing after it.
    setTimeout(function () { window.location.href = link.getAttribute('href'); }, 350);
  })();
</script>
</body>
</html>`))
