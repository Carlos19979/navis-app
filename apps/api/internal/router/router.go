package router

import (
	"log/slog"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/handler"
	"github.com/Carlos19979/navis-app/apps/api/internal/middleware"
)

// New creates and configures the chi router with all routes and middleware.
func New(
	boatH *handler.BoatHandler,
	docH *handler.DocumentHandler,
	tripH *handler.TripHandler,
	eventH *handler.EventHandler,
	groupH *handler.GroupHandler,
	portH *handler.PortHandler,
	weatherH *handler.WeatherHandler,
	deviceH *handler.DeviceHandler,
	userH *handler.UserHandler,
	jwtSecret string,
	jwksURL string,
	allowedOrigins []string,
	logger *slog.Logger,
) chi.Router {
	r := chi.NewRouter()

	// Global middleware chain.
	r.Use(middleware.RequestID)
	r.Use(middleware.Recovery(logger))
	r.Use(middleware.SecurityHeaders)
	r.Use(middleware.CORS(allowedOrigins))
	r.Use(middleware.RateLimit(100, time.Minute))
	r.Use(middleware.Logging(logger))

	// Health check endpoints (no auth required).
	r.Get("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	})
	r.Get("/readyz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	})

	// Keep /health as alias for backwards compatibility.
	r.Get("/health", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	})

	// API v1 routes (all require authentication).
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(middleware.Auth(jwtSecret, jwksURL))

		// Boats CRUD.
		r.Route("/boats", func(r chi.Router) {
			r.Post("/", boatH.Create)
			r.Get("/", boatH.List)

			r.Route("/{id}", func(r chi.Router) {
				r.Get("/", boatH.GetByID)
				r.Put("/", boatH.Update)
				r.Delete("/", boatH.Delete)

				r.Route("/documents", func(r chi.Router) {
					r.Post("/", docH.Create)
					r.Get("/", docH.ListByBoat)
				})

				r.Route("/trips", func(r chi.Router) {
					r.Post("/", tripH.Create)
					r.Get("/", tripH.List)
				})
			})
		})

		// Documents (top-level for get, update, delete).
		r.Route("/documents", func(r chi.Router) {
			r.Route("/{id}", func(r chi.Router) {
				r.Get("/", docH.GetByID)
				r.Put("/", docH.Update)
				r.Delete("/", docH.Delete)
			})
		})

		// Trips (top-level for get, update, complete, tracks).
		r.Route("/trips", func(r chi.Router) {
			r.Route("/{id}", func(r chi.Router) {
				r.Get("/", tripH.GetByID)
				r.Put("/", tripH.Update)
				r.Delete("/", tripH.Delete)
				r.Put("/complete", tripH.Complete)
				r.Get("/tracks", tripH.GetTracks)
				r.Post("/tracks", tripH.AddTracks)
			})
		})

		// Ports (nearby search).
		r.Route("/ports", func(r chi.Router) {
			r.Get("/nearby", portH.Nearby)

			r.Route("/{id}", func(r chi.Router) {
				r.Get("/", portH.GetByID)
			})
		})

		// Events.
		r.Route("/events", func(r chi.Router) {
			r.Get("/", eventH.List)

			r.Route("/{id}", func(r chi.Router) {
				r.Get("/", eventH.GetByID)
				r.Post("/interest", eventH.ToggleInterest)
			})
		})

		// Groups (clubs / crews).
		r.Route("/groups", func(r chi.Router) {
			r.Post("/", groupH.Create)
			r.Get("/", groupH.List)
			r.Post("/join", groupH.JoinByCode)

			r.Route("/{id}", func(r chi.Router) {
				r.Get("/", groupH.GetByID)
				r.Put("/", groupH.Update)
				r.Delete("/", groupH.Delete)
				r.Post("/join", groupH.RequestJoin)
				r.Post("/leave", groupH.Leave)

				r.Route("/members", func(r chi.Router) {
					r.Get("/", groupH.ListMembers)
					r.Delete("/{userId}", groupH.RemoveMember)
				})

				r.Route("/requests", func(r chi.Router) {
					r.Get("/", groupH.ListRequests)
					r.Post("/{userId}/approve", groupH.ApproveRequest)
					r.Post("/{userId}/reject", groupH.RejectRequest)
				})
			})
		})

		// Weather.
		r.Route("/weather", func(r chi.Router) {
			r.Get("/current", weatherH.GetCurrent)
			r.Get("/forecast", weatherH.GetForecast)
		})

		// Device tokens for push notifications.
		r.Route("/devices", func(r chi.Router) {
			r.Post("/", deviceH.Create)
			r.Delete("/{token}", deviceH.Delete)
		})

		// User account (GDPR).
		r.Route("/user", func(r chi.Router) {
			r.Get("/export", userH.ExportData)
			r.Delete("/", userH.DeleteAccount)
		})
	})

	return r
}
