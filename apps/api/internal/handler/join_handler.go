package handler

import (
	"html/template"
	"net/http"
	"regexp"
	"strings"
)

// StoreLinks are the app's download URLs, shown on the join page when the app
// is not installed. Empty links are simply not rendered: an App Store URL only
// exists once the app is published, and a dead button is worse than none.
type StoreLinks struct {
	IOS     string
	Android string
}

// JoinHandler serves GET /join?code=XXXX — the page an invite link lands on.
//
// Invites used to carry `navis://join?code=…` as their only link. That is not
// something a recipient can use: messaging apps do not turn a custom scheme
// into a tappable link, and on a phone without Navis nothing happens at all.
// This page is an ordinary https URL that every app linkifies, and it does the
// two things the sender expects — open the app when it is installed, offer the
// download when it is not.
type JoinHandler struct {
	stores StoreLinks
}

// NewJoinHandler creates a JoinHandler.
func NewJoinHandler(stores StoreLinks) *JoinHandler {
	return &JoinHandler{stores: stores}
}

// joinCodePattern matches the share codes the API generates (see
// BoatService.ShareCode, currently 8 uppercase alphanumerics — the range gives
// room to change the length without breaking old links). Anything else is
// treated as no code at all rather than echoed back into the page.
var joinCodePattern = regexp.MustCompile(`^[A-Z0-9]{6,12}$`)

// Join handles GET /join.
func (h *JoinHandler) Join(w http.ResponseWriter, r *http.Request) {
	code := strings.ToUpper(strings.TrimSpace(r.URL.Query().Get("code")))
	if !joinCodePattern.MatchString(code) {
		code = ""
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	// The code is single-use-ish and not secret, but it is still an invite:
	// keep it out of shared caches.
	w.Header().Set("Cache-Control", "no-store")
	_ = joinPageTemplate.Execute(w, map[string]any{
		"Code": code,
		// template.URL because html/template rewrites any scheme it does not
		// recognise to "#ZgotmplZ", which silently broke the one link that
		// matters here. Safe: the scheme is a constant and `code` has just been
		// matched against joinCodePattern.
		//nolint:gosec // G203: constant scheme + regexp-validated code
		"DeepLink":     template.URL("navis://join?code=" + code),
		"IOSStore":     h.stores.IOS,
		"AndroidStore": h.stores.Android,
		"HasStore":     h.stores.IOS != "" || h.stores.Android != "",
	})
}

// The page tries the app immediately (a hidden iframe/location assignment does
// not leave a visible error page if the scheme is unhandled) and then shows the
// code plus the download options. Everything is inline: no external assets, so
// it works under the strict CSP the public pages ship with.
var joinPageTemplate = template.Must(template.New("join").Parse(`<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Únete a un barco en Navis</title>
<meta name="description" content="Te han invitado a un barco en Navis, el cuaderno de bitácora y gestor de mantenimiento para tu embarcación.">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Navis">
<meta property="og:title" content="Únete a un barco en Navis">
<meta property="og:description" content="Abre la invitación en Navis o descarga la app para aceptarla.">
<style>
  :root { --navy:#1B2A4A; --deep:#0e1830; --cyan:#4DA8DA; --muted:#9fb3d1; }
  * { box-sizing:border-box; margin:0; padding:0; }
  body { font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
         background:var(--navy); color:#fff; min-height:100vh;
         display:flex; align-items:center; justify-content:center; padding:24px; }
  .card { width:100%; max-width:420px; text-align:center; }
  .mark { font-size:44px; line-height:1; margin-bottom:14px; }
  h1 { font-size:24px; font-weight:700; margin-bottom:8px; }
  p { color:var(--muted); font-size:15px; line-height:1.55; }
  .code { margin:22px 0; padding:18px; border-radius:14px; letter-spacing:6px;
          font-size:26px; font-weight:800; color:var(--cyan);
          background:rgba(77,168,218,.12); border:1px solid rgba(77,168,218,.4); }
  a.btn { display:block; text-decoration:none; font-weight:700; padding:15px;
          border-radius:14px; margin-top:10px; }
  a.primary { background:var(--cyan); color:#06203a; }
  a.secondary { background:rgba(255,255,255,.08); color:#fff;
                border:1px solid rgba(255,255,255,.18); }
  .hint { margin-top:18px; font-size:13px; color:var(--muted); }
</style>
</head>
<body>
<div class="card">
  <div class="mark">⛵</div>
  <h1>Te han invitado a un barco</h1>
  {{if .Code}}
  <p>Abre la invitación en Navis. Si aún no tienes la app, descárgala y entra con este código.</p>
  <div class="code">{{.Code}}</div>
  <a class="btn primary" id="open" href="{{.DeepLink}}">Abrir en Navis</a>
  {{else}}
  <p>Este enlace no lleva un código válido. Pide a quien te invitó que vuelva a compartirlo.</p>
  {{end}}
  {{if .HasStore}}
    {{if .IOSStore}}<a class="btn secondary" href="{{.IOSStore}}">Descargar para iPhone</a>{{end}}
    {{if .AndroidStore}}<a class="btn secondary" href="{{.AndroidStore}}">Descargar para Android</a>{{end}}
  {{else}}
  <p class="hint">Navis estará disponible próximamente en el App Store y en Google Play. Guarda este código: sirve para unirte cuando instales la app.</p>
  {{end}}
  <p class="hint">Navis · cuaderno de bitácora y mantenimiento de tu barco</p>
</div>
{{if .Code}}
<script>
  // Try the app straight away. If the scheme is not handled nothing happens
  // and the page stays as the fallback, which is the whole point.
  (function () {
    var link = document.getElementById('open');
    var tried = false;
    function open() {
      if (tried) return;
      tried = true;
      window.location.href = link.getAttribute('href');
    }
    // A tick after paint, so the page is already visible behind the prompt.
    setTimeout(open, 350);
  })();
</script>
{{end}}
</body>
</html>`))
