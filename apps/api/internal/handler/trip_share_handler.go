package handler

import (
	"encoding/json"
	"fmt"
	"html/template"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
)

// publicTripURL builds the shareable public URL for a trip token.
func publicTripURL(r *http.Request, token string) string {
	scheme := "http"
	if r.TLS != nil || r.Header.Get("X-Forwarded-Proto") == "https" {
		scheme = "https"
	}
	return fmt.Sprintf("%s://%s/public/trips/%s/view", scheme, r.Host, token)
}

// Share handles PUT /trips/{id}/share — makes a trip public and returns its link.
func (h *TripHandler) Share(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	tripID := chi.URLParam(r, "id")

	token, err := h.svc.Share(r.Context(), userID, tripID)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.ShareTripResponse{
		Token: token,
		URL:   publicTripURL(r, token),
	})
}

// Unshare handles DELETE /trips/{id}/share — revokes the public link.
func (h *TripHandler) Unshare(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}
	tripID := chi.URLParam(r, "id")

	if err := h.svc.Unshare(r.Context(), userID, tripID); err != nil {
		MapDomainError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// PublicJSON handles GET /public/trips/{token} (no auth) — JSON view.
func (h *TripHandler) PublicJSON(w http.ResponseWriter, r *http.Request) {
	token := chi.URLParam(r, "token")
	trip, track, err := h.svc.PublicByToken(r.Context(), token)
	if err != nil {
		MapDomainError(w, err)
		return
	}
	JSON(w, http.StatusOK, dto.PublicTripResponseFromDomain(trip, track))
}

// PublicView handles GET /public/trips/{token}/view (no auth) — an HTML page
// with a map of the route. This is the growth/share landing page.
func (h *TripHandler) PublicView(w http.ResponseWriter, r *http.Request) {
	token := chi.URLParam(r, "token")
	trip, track, err := h.svc.PublicByToken(r.Context(), token)
	if err != nil {
		http.Error(w, "Trip not found", http.StatusNotFound)
		return
	}

	pts := make([][2]float64, len(track))
	for i := range track {
		pts[i] = [2]float64{track[i].Lat, track[i].Lon}
	}
	coordsJSON, _ := json.Marshal(pts)

	arrival := "—"
	if trip.ArrivalPort != nil && *trip.ArrivalPort != "" {
		arrival = *trip.ArrivalPort
	}
	distance := "—"
	if trip.DistanceNM != nil {
		distance = fmt.Sprintf("%.1f NM", *trip.DistanceNM)
	}
	duration := "—"
	if trip.DurationMinutes != nil {
		duration = fmt.Sprintf("%dh %dm", *trip.DurationMinutes/60, *trip.DurationMinutes%60)
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_ = publicTripTemplate.Execute(w, map[string]any{
		"Departure": trip.DeparturePort,
		"Arrival":   arrival,
		"Date":      trip.DepartureTime.Format("02/01/2006"),
		"Distance":  distance,
		"Duration":  duration,
		//nolint:gosec // G203: coordsJSON is json.Marshal output of server-side floats (lat/lng), never user-controlled strings
		"Coords": template.JS(coordsJSON),
	})
}

var publicTripTemplate = template.Must(template.New("trip").Parse(`<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{.Departure}} → {{.Arrival}} · Navis</title>
<meta name="description" content="Travesía de {{.Departure}} a {{.Arrival}} ({{.Distance}}, {{.Duration}}) registrada con Navis, el cuaderno de bitácora digital.">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Navis">
<meta property="og:title" content="{{.Departure}} → {{.Arrival}} · Navis">
<meta property="og:description" content="Travesía de {{.Distance}} en {{.Duration}} el {{.Date}}. Mira la ruta en el mapa.">
<meta name="twitter:card" content="summary">
<meta name="twitter:title" content="{{.Departure}} → {{.Arrival}} · Navis">
<meta name="twitter:description" content="Travesía de {{.Distance}} en {{.Duration}} el {{.Date}}. Mira la ruta en el mapa.">
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
<style>
  :root { --navy:#1B2A4A; --cyan:#4DA8DA; }
  * { box-sizing:border-box; margin:0; padding:0; }
  body { font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif; background:var(--navy); color:#fff; }
  #map { height:55vh; width:100%; background:#0e1830; }
  .panel { padding:20px; max-width:680px; margin:0 auto; }
  .route { font-size:22px; font-weight:700; margin-bottom:4px; }
  .date { color:#9fb3d1; margin-bottom:18px; }
  .stats { display:flex; gap:12px; flex-wrap:wrap; }
  .stat { flex:1; min-width:120px; background:rgba(255,255,255,.06); border:1px solid rgba(255,255,255,.12);
          border-radius:14px; padding:14px; }
  .stat .v { font-size:20px; font-weight:700; }
  .stat .l { color:#9fb3d1; font-size:13px; }
  .cta { display:block; text-align:center; margin:24px auto 0; background:var(--cyan); color:#06203a;
         text-decoration:none; font-weight:700; padding:14px; border-radius:14px; max-width:280px; }
  .brand { text-align:center; color:#9fb3d1; margin-top:14px; font-size:13px; }
</style>
</head>
<body>
<div id="map"></div>
<div class="panel">
  <div class="route">{{.Departure}} → {{.Arrival}}</div>
  <div class="date">{{.Date}}</div>
  <div class="stats">
    <div class="stat"><div class="v">{{.Distance}}</div><div class="l">Distancia</div></div>
    <div class="stat"><div class="v">{{.Duration}}</div><div class="l">Duración</div></div>
  </div>
  <a class="cta" href="https://navis.app">Gestiona tu barco con Navis</a>
  <div class="brand">⛵ Compartido desde Navis</div>
</div>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script>
  var coords = {{.Coords}};
  var map = L.map('map', { zoomControl:true, attributionControl:false });
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom:18 }).addTo(map);
  L.tileLayer('https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png', { maxZoom:18 }).addTo(map);
  if (coords && coords.length) {
    var line = L.polyline(coords, { color:'#4DA8DA', weight:4 }).addTo(map);
    L.circleMarker(coords[0], { color:'#2ECC71', radius:6 }).addTo(map);
    L.circleMarker(coords[coords.length-1], { color:'#E74C3C', radius:6 }).addTo(map);
    map.fitBounds(line.getBounds(), { padding:[30,30] });
  } else {
    map.setView([39.5, 2.6], 8);
  }
</script>
</body>
</html>`))
