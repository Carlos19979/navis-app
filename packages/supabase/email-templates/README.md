# Plantillas de correo de Supabase Auth

Los correos que manda GoTrue (recuperar contraseña, confirmar alta, cambiar
email…) **no se despliegan con el repo**: viven en la configuración del
proyecto. Se guardan aquí para que existan en algún sitio revisable y para
poder volver a aplicarlas, no porque nada las lea en tiempo de ejecución.

## Por qué no valen las de fábrica

La plantilla por defecto de Supabase es HTML pelado, sin una sola declaración
de estilo:

```html
<h2>Reset your password</h2>
<p>We received a request to reset your password…</p>
<p><a href="{{ .ConfirmationURL }}">Reset password</a></p>
```

Sin `color` declarado cada cliente de correo pinta lo que quiere —el texto
salía verde en el móvil—, y encima llega en inglés en una app que es española
y sin nada que la identifique como Navis.

## Aplicarlas

No hay `supabase db push` para esto: es la Management API (o el dashboard, en
Authentication → Emails). Con `SUPABASE_ACCESS_TOKEN` y `SUPABASE_PROJECT_REF`
en `~/.config/navis/tokens.env` (ver `docs/dev-access.md`):

```bash
python3 - <<'PY'
import json, os, pathlib, urllib.request
tpl = pathlib.Path('packages/supabase/email-templates/recovery.es.html').read_text()
body = json.dumps({
    'mailer_subjects_recovery': 'Restablece tu contraseña de Navis',
    'mailer_templates_recovery_content': tpl,
}).encode()
req = urllib.request.Request(
    f"https://api.supabase.com/v1/projects/{os.environ['SUPABASE_PROJECT_REF']}/config/auth",
    data=body, method='PATCH',
    headers={'Authorization': f"Bearer {os.environ['SUPABASE_ACCESS_TOKEN']}",
             'Content-Type': 'application/json'})
print(urllib.request.urlopen(req).status)
PY
```

### No es inmediato

GoTrue tarda **unos minutos** en recoger el cambio. Justo despues del PATCH la
API ya devuelve la plantilla nueva pero los correos siguen saliendo con la de
fabrica, asunto incluido — parece que no ha funcionado y no es verdad. Medido:
a los 20 s y a los 2 min seguia la vieja, a los ~5 min ya salia la nueva.
Comprueba con un correo real, no releyendo la config:

```bash
# el HTML tal y como se entrego, via Resend
curl -sS -H "Authorization: Bearer $RESEND_API_KEY" \
  "https://api.resend.com/emails?limit=1" | jq -r '.data[0].id' \
  | xargs -I{} curl -sS -H "Authorization: Bearer $RESEND_API_KEY" \
    "https://api.resend.com/emails/{}" | jq -r '.subject, .html'
```

## Al escribirlas

- **Declara el color de cada texto.** Es el fallo original: lo que no declaras
  lo decide el cliente.
- Tablas y estilos en línea. Nada de `<style>`, `flex`, `grid` ni assets
  externos: la mitad de los clientes no los entienden.
- `{{ .ConfirmationURL }}` es la variable de GoTrue. Si se pierde, el correo
  llega sin enlace y el flujo entero muere en silencio.
- Acentos como entidades HTML (`&oacute;`), que sobreviven a cualquier
  codificación por la que pase el correo.

## Lo que falta

Solo está hecha la de recuperación. Las demás (`confirmation`, `email_change`,
`magic_link`, `invite`) siguen siendo las de fábrica, en inglés y sin estilo —
y la de confirmación de alta la ve **todo** el que se registra, porque
`mailer_autoconfirm` está desactivado.
