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
	regattaH *handler.RegattaHandler,
	portH *handler.PortHandler,
	weatherH *handler.WeatherHandler,
	deviceH *handler.DeviceHandler,
	userH *handler.UserHandler,
	profileH *handler.ProfileHandler,
	maintenanceH *handler.MaintenanceHandler,
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

	// Public shared trips (no auth) — the share/landing pages.
	r.Route("/public/trips", func(r chi.Router) {
		r.Get("/{token}", tripH.PublicJSON)
		r.Get("/{token}/view", tripH.PublicView)
	})

	// API v1 routes (all require authentication).
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(middleware.Auth(jwtSecret, jwksURL))

		// Boats CRUD.
		r.Route("/boats", func(r chi.Router) {
			r.Post("/", boatH.Create)
			r.Get("/", boatH.List)
			r.Get("/shared", boatH.ListShared)
			r.Post("/join", boatH.Join)

			r.Route("/{id}", func(r chi.Router) {
				r.Get("/", boatH.GetByID)
				r.Put("/", boatH.Update)
				r.Delete("/", boatH.Delete)
				r.Put("/share-code", boatH.ShareCode)
				r.Post("/leave", boatH.Leave)
				r.Route("/members", func(r chi.Router) {
					r.Get("/", boatH.ListMembers)
					r.Delete("/{userId}", boatH.RemoveMember)
				})

				r.Route("/documents", func(r chi.Router) {
					r.Post("/", docH.Create)
					r.Get("/", docH.ListByBoat)
				})

				r.Route("/trips", func(r chi.Router) {
					r.Post("/", tripH.Create)
					r.Get("/", tripH.List)
				})

				r.Route("/maintenance", func(r chi.Router) {
					r.Get("/", maintenanceH.ListLogs)
					r.Post("/", maintenanceH.CreateLog)
					r.Delete("/{logId}", maintenanceH.DeleteLog)
				})

				r.Route("/expenses", func(r chi.Router) {
					r.Get("/", maintenanceH.ListExpenses)
					r.Post("/", maintenanceH.CreateExpense)
					r.Get("/summary", maintenanceH.ExpenseSummary)
					r.Delete("/{expenseId}", maintenanceH.DeleteExpense)
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
				r.Put("/share", tripH.Share)
				r.Delete("/share", tripH.Unshare)
				r.Put("/float-plan", tripH.SetFloatPlan)

				// Regatta lifecycle + RSVP.
				r.Put("/start", regattaH.Start)
				r.Put("/cancel", regattaH.Cancel)
				r.Put("/revert", regattaH.Revert)
				r.Post("/rsvp", regattaH.SetRSVP)
				r.Get("/participants", regattaH.ListParticipants)

				// Pre-departure safety checklist.
				r.Route("/checklist", func(r chi.Router) {
					r.Get("/", regattaH.GetChecklist)
					r.Post("/", regattaH.AddChecklistItem)
					r.Put("/complete", regattaH.CompleteChecklist)
					r.Put("/{itemId}", regattaH.SetChecklistItem)
					r.Delete("/{itemId}", regattaH.RemoveChecklistItem)
				})
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

				// Group regattas / outings.
				r.Get("/trips", regattaH.ListGroupTrips)
				r.Post("/trips", regattaH.Schedule)
			})
		})

		// Weather.
		r.Route("/weather", func(r chi.Router) {
			r.Get("/current", weatherH.GetCurrent)
			r.Get("/forecast", weatherH.GetForecast)
			r.Get("/overview", weatherH.GetOverview)
			r.Get("/hourly", weatherH.GetHourly)
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

		// Current user's plan and limits.
		r.Route("/me", func(r chi.Router) {
			r.Get("/", profileH.Me)
			r.Put("/plan", profileH.UpdatePlan)
		})
	})

	return r
}
