package handler

// Draft legal texts served by LegalHandler. Spanish first, English below.
//
// ⚠️ REVIEW BEFORE LAUNCH: replace the [PLACEHOLDER] identity/contact values
// and have the wording reviewed — the app operator is legally responsible for
// these documents.

const privacyBody = `
<h1>Política de Privacidad</h1>
<p class="updated">Última actualización: 11 de julio de 2026</p>

<h2>1. Responsable del tratamiento</h2>
<p>[NOMBRE DEL TITULAR O EMPRESA], con domicilio en [DIRECCIÓN] (el «Responsable»),
opera la aplicación móvil Navis (la «App»). Contacto de privacidad:
<a href="mailto:soporte@aerolume.app">soporte@aerolume.app</a>.</p>

<h2>2. Datos que tratamos</h2>
<table>
<tr><th>Categoría</th><th>Datos</th><th>Finalidad</th></tr>
<tr><td>Cuenta</td><td>Email, nombre, identificador de usuario</td><td>Autenticación y gestión de la cuenta</td></tr>
<tr><td>Barcos y documentos</td><td>Datos del barco, documentos náuticos escaneados (pueden contener datos personales como pólizas o certificados)</td><td>Funcionalidad principal: gestión documental y recordatorios de caducidad</td></tr>
<tr><td>Ubicación</td><td>Posición GPS durante la grabación de rutas (también en segundo plano si lo autorizas)</td><td>Registro de travesías en tu cuaderno de bitácora</td></tr>
<tr><td>Mantenimiento y gastos</td><td>Registros de mantenimiento, importes, facturas adjuntas</td><td>Historial de mantenimiento del barco</td></tr>
<tr><td>Dispositivo</td><td>Token de notificaciones push, plataforma</td><td>Envío de recordatorios y avisos</td></tr>
<tr><td>Suscripción</td><td>Estado de la suscripción (Free/Pro). El pago lo procesa Apple; no vemos tus datos de pago</td><td>Activación del plan Pro</td></tr>
</table>

<h2>3. Base jurídica</h2>
<p>Tratamos tus datos para ejecutar el contrato (art. 6.1.b RGPD: prestarte el
servicio), por interés legítimo (art. 6.1.f: seguridad y prevención de fraude) y
con tu consentimiento cuando lo solicitamos expresamente (art. 6.1.a: ubicación
en segundo plano, notificaciones).</p>

<h2>4. Encargados del tratamiento</h2>
<p>Usamos proveedores que tratan datos por nuestra cuenta:</p>
<table>
<tr><th>Proveedor</th><th>Servicio</th><th>Ubicación</th></tr>
<tr><td>Supabase</td><td>Base de datos, autenticación y almacenamiento de archivos</td><td>UE</td></tr>
<tr><td>Railway</td><td>Alojamiento de la API</td><td>UE</td></tr>
<tr><td>RevenueCat</td><td>Gestión de suscripciones</td><td>EE. UU. (Cláusulas Contractuales Tipo)</td></tr>
<tr><td>Sentry</td><td>Informes de errores (sin datos sensibles)</td><td>EE. UU. (CCT)</td></tr>
<tr><td>Novu / Resend</td><td>Orquestación y envío de notificaciones y correos</td><td>EE. UU. (CCT)</td></tr>
<tr><td>Google Firebase (FCM)</td><td>Entrega de notificaciones push</td><td>EE. UU. (CCT)</td></tr>
<tr><td>Open-Meteo</td><td>Datos meteorológicos (solo recibe coordenadas, nunca tu identidad)</td><td>UE</td></tr>
</table>

<h2>5. Conservación</h2>
<p>Conservamos tus datos mientras mantengas tu cuenta. Al eliminarla (Ajustes →
Cuenta → Eliminar cuenta) se borran de forma permanente tu usuario, tus datos y
tus archivos. Podemos conservar registros técnicos anonimizados.</p>

<h2>6. Tus derechos</h2>
<p>Puedes ejercer tus derechos de acceso, rectificación, supresión, portabilidad,
limitación y oposición. Dentro de la App: exporta todos tus datos (Perfil →
Exportar datos) o elimina tu cuenta. También por email a
<a href="mailto:soporte@aerolume.app">soporte@aerolume.app</a>. Tienes derecho a
reclamar ante la Agencia Española de Protección de Datos (aepd.es).</p>

<h2>7. Seguridad</h2>
<p>Los datos viajan cifrados (TLS) y los documentos se almacenan en un bucket
privado accesible solo con URLs firmadas. El acceso a la API requiere
autenticación.</p>

<h2>8. Menores</h2>
<p>La App no está dirigida a menores de 16 años.</p>

<h2>9. Cambios</h2>
<p>Publicaremos aquí cualquier cambio de esta política y actualizaremos la fecha
de «última actualización».</p>

<hr class="lang">

<h1>Privacy Policy</h1>
<p class="updated">Last updated: July 11, 2026</p>

<h2>1. Data controller</h2>
<p>[OWNER OR COMPANY NAME], located at [ADDRESS] (the "Controller"), operates the
Navis mobile application (the "App"). Privacy contact:
<a href="mailto:soporte@aerolume.app">soporte@aerolume.app</a>.</p>

<h2>2. Data we process</h2>
<table>
<tr><th>Category</th><th>Data</th><th>Purpose</th></tr>
<tr><td>Account</td><td>Email, name, user identifier</td><td>Authentication and account management</td></tr>
<tr><td>Boats & documents</td><td>Boat details, scanned nautical documents (may contain personal data such as insurance policies or certificates)</td><td>Core functionality: document management and expiry reminders</td></tr>
<tr><td>Location</td><td>GPS position while recording routes (including in the background if you allow it)</td><td>Recording passages in your logbook</td></tr>
<tr><td>Maintenance & expenses</td><td>Maintenance logs, amounts, attached invoices</td><td>Boat maintenance history</td></tr>
<tr><td>Device</td><td>Push notification token, platform</td><td>Delivering reminders and alerts</td></tr>
<tr><td>Subscription</td><td>Subscription status (Free/Pro). Payment is processed by Apple; we never see your payment details</td><td>Enabling the Pro plan</td></tr>
</table>

<h2>3. Legal basis</h2>
<p>We process your data to perform our contract with you (Art. 6(1)(b) GDPR),
for legitimate interests (Art. 6(1)(f): security and fraud prevention), and with
your consent where we expressly ask for it (Art. 6(1)(a): background location,
notifications).</p>

<h2>4. Processors</h2>
<p>We rely on providers processing data on our behalf: Supabase (database, auth,
file storage — EU), Railway (API hosting — EU), RevenueCat (subscriptions — US,
SCCs), Sentry (error reporting — US, SCCs), Novu/Resend (notifications and email
— US, SCCs), Google Firebase FCM (push delivery — US, SCCs) and Open-Meteo
(weather; receives coordinates only, never your identity — EU).</p>

<h2>5. Retention</h2>
<p>We keep your data for as long as you keep your account. Deleting your account
(Settings → Account → Delete account) permanently removes your user, data and
files. We may retain anonymised technical logs.</p>

<h2>6. Your rights</h2>
<p>You may exercise your rights of access, rectification, erasure, portability,
restriction and objection. In-app: export all your data (Profile → Export data)
or delete your account. You can also email
<a href="mailto:soporte@aerolume.app">soporte@aerolume.app</a>. You have the
right to lodge a complaint with your supervisory authority.</p>

<h2>7. Security</h2>
<p>Data is encrypted in transit (TLS) and documents are stored in a private
bucket accessible only through signed URLs. API access requires authentication.</p>

<h2>8. Children</h2>
<p>The App is not directed at children under 16.</p>

<h2>9. Changes</h2>
<p>Changes to this policy will be published here with an updated date.</p>
`

const termsBody = `
<h1>Términos de Servicio</h1>
<p class="updated">Última actualización: 11 de julio de 2026</p>

<h2>1. El servicio</h2>
<p>Navis es una aplicación de gestión de embarcaciones de recreo: documentación
con recordatorios de caducidad, cuaderno de bitácora con rutas GPS, mantenimiento,
gastos, grupos y meteorología. El servicio lo presta [NOMBRE DEL TITULAR O
EMPRESA] («nosotros»). Al crear una cuenta aceptas estos términos.</p>

<h2>2. Uso de la información náutica — aviso importante</h2>
<p><strong>Navis no es un instrumento de navegación ni un sistema de seguridad.</strong>
Los datos meteorológicos, de mareas y cartográficos se ofrecen únicamente a
título informativo, pueden ser inexactos y no deben usarse como única fuente
para decisiones de navegación. Consulta siempre fuentes oficiales y respeta la
normativa marítima aplicable.</p>

<h2>3. Tu cuenta y contenido</h2>
<p>Eres responsable de la exactitud de los datos que registras y de los
documentos que subes, así como de mantener la confidencialidad de tu acceso.
Conservas la titularidad de tu contenido; nos concedes una licencia limitada
para almacenarlo y procesarlo con el único fin de prestarte el servicio.</p>

<h2>4. Suscripción Navis Pro</h2>
<ul>
<li>Navis Pro es una suscripción auto-renovable (mensual: 3,99 € · anual: 29,99 €;
precios finales según tu App Store local).</li>
<li>El pago se carga a tu cuenta de Apple al confirmar la compra. La suscripción
se renueva automáticamente salvo que la canceles al menos 24 horas antes del
final del período en curso.</li>
<li>Gestiona o cancela la suscripción en los ajustes de tu cuenta del App Store.
La cancelación surte efecto al final del período ya pagado.</li>
<li>Al eliminar tu cuenta no se cancela la suscripción automáticamente:
cancélala también en el App Store.</li>
</ul>

<h2>5. Uso aceptable</h2>
<p>No puedes usar la App para fines ilícitos, intentar acceder a datos de otros
usuarios, interferir con el servicio o realizar ingeniería inversa salvo donde
la ley lo permita.</p>

<h2>6. Disponibilidad y cambios</h2>
<p>Podemos modificar o interrumpir funciones, y actualizaremos estos términos
cuando sea necesario; los cambios relevantes se comunicarán en la App. El uso
continuado tras un cambio supone su aceptación.</p>

<h2>7. Responsabilidad</h2>
<p>En la medida permitida por la ley, la App se ofrece «tal cual» y no
garantizamos que esté libre de errores. No respondemos de daños derivados de
decisiones de navegación basadas en la información de la App ni de pérdidas de
datos causadas por factores fuera de nuestro control razonable. Nada en estos
términos limita derechos que la ley te reconozca como consumidor.</p>

<h2>8. Terminación</h2>
<p>Puedes eliminar tu cuenta en cualquier momento (Ajustes → Cuenta). Podemos
suspender cuentas que incumplan estos términos.</p>

<h2>9. Ley aplicable</h2>
<p>Estos términos se rigen por la legislación española. Cualquier disputa se
someterá a los juzgados del domicilio del consumidor.</p>

<h2>10. Contacto</h2>
<p><a href="mailto:soporte@aerolume.app">soporte@aerolume.app</a></p>

<hr class="lang">

<h1>Terms of Service</h1>
<p class="updated">Last updated: July 11, 2026</p>

<h2>1. The service</h2>
<p>Navis is a recreational boat management app: documents with expiry reminders,
GPS logbook, maintenance, expenses, groups and weather. The service is provided
by [OWNER OR COMPANY NAME] ("we"). By creating an account you accept these terms.</p>

<h2>2. Use of nautical information — important notice</h2>
<p><strong>Navis is not a navigation instrument or a safety system.</strong>
Weather, tide and chart data are provided for information only, may be
inaccurate, and must not be used as the sole source for navigation decisions.
Always consult official sources and comply with applicable maritime law.</p>

<h2>3. Your account and content</h2>
<p>You are responsible for the accuracy of the data you record and the documents
you upload, and for keeping your access credentials confidential. You retain
ownership of your content; you grant us a limited licence to store and process
it solely to provide the service.</p>

<h2>4. Navis Pro subscription</h2>
<ul>
<li>Navis Pro is an auto-renewable subscription (monthly €3.99 · yearly €29.99;
final prices per your local App Store).</li>
<li>Payment is charged to your Apple account at purchase confirmation. The
subscription renews automatically unless cancelled at least 24 hours before the
end of the current period.</li>
<li>Manage or cancel it in your App Store account settings. Cancellation takes
effect at the end of the paid period.</li>
<li>Deleting your account does not automatically cancel the subscription:
cancel it in the App Store as well.</li>
</ul>

<h2>5. Acceptable use</h2>
<p>You may not use the App for unlawful purposes, attempt to access other
users' data, interfere with the service, or reverse-engineer it except where
permitted by law.</p>

<h2>6. Availability and changes</h2>
<p>We may modify or discontinue features and will update these terms when
needed; material changes will be communicated in the App. Continued use after a
change constitutes acceptance.</p>

<h2>7. Liability</h2>
<p>To the extent permitted by law, the App is provided "as is" and we do not
guarantee it is error-free. We are not liable for damages arising from
navigation decisions based on the App's information, or for data loss caused by
factors beyond our reasonable control. Nothing in these terms limits rights you
have as a consumer under applicable law.</p>

<h2>8. Termination</h2>
<p>You may delete your account at any time (Settings → Account). We may suspend
accounts that breach these terms.</p>

<h2>9. Governing law</h2>
<p>These terms are governed by Spanish law. Disputes will be submitted to the
courts of the consumer's domicile.</p>

<h2>10. Contact</h2>
<p><a href="mailto:soporte@aerolume.app">soporte@aerolume.app</a></p>
`
