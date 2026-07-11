package handler

import (
	"html/template"
	"net/http"
)

// LegalHandler serves the privacy policy and terms of service as standalone
// HTML pages. App Store Connect and the in-app links point here.
//
// ⚠️ The documents are drafts: the identity/contact placeholders and the legal
// wording must be reviewed by the operator before launch (see docs/deploy.md).
type LegalHandler struct{}

// NewLegalHandler creates a LegalHandler.
func NewLegalHandler() *LegalHandler {
	return &LegalHandler{}
}

// Privacy handles GET /legal/privacy.
func (h *LegalHandler) Privacy(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_ = legalPageTemplate.Execute(w, map[string]any{
		"Title": "Política de Privacidad · Privacy Policy · Navis",
		"Body":  template.HTML(privacyBody), //nolint:gosec // static server-side content
	})
}

// Terms handles GET /legal/terms.
func (h *LegalHandler) Terms(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_ = legalPageTemplate.Execute(w, map[string]any{
		"Title": "Términos de Servicio · Terms of Service · Navis",
		"Body":  template.HTML(termsBody), //nolint:gosec // static server-side content
	})
}

var legalPageTemplate = template.Must(template.New("legal").Parse(`<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{.Title}}</title>
<style>
  :root { --navy:#1B2A4A; --cyan:#4DA8DA; }
  * { box-sizing:border-box; }
  body { font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
         margin:0; background:#fff; color:#1c2430; line-height:1.6; }
  header { background:var(--navy); color:#fff; padding:24px 20px; }
  header h1 { margin:0; font-size:1.4rem; }
  main { max-width:760px; margin:0 auto; padding:24px 20px 64px; }
  h2 { color:var(--navy); margin-top:2em; font-size:1.2rem; }
  h3 { color:var(--navy); font-size:1.05rem; }
  hr.lang { margin:48px 0; border:none; border-top:3px solid var(--cyan); }
  table { border-collapse:collapse; width:100%; font-size:0.95rem; }
  th, td { border:1px solid #d5dbe3; padding:8px 10px; text-align:left; vertical-align:top; }
  th { background:#f2f5f9; }
  .updated { color:#5a6675; font-size:0.9rem; }
</style>
</head>
<body>
<header><h1>Navis</h1></header>
<main>
{{.Body}}
</main>
</body>
</html>`))
