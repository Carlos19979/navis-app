package router

import (
	"context"
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
	readinessH *handler.ReadinessHandler,
	costH *handler.CostHandler,
	sharedH *handler.SharedHandler,
	anomalyH *handler.AnomalyHandler,
	webhookH *handler.WebhookHandler,
	legalH *handler.LegalHandler,
	jwtSecret string,
	jwksURL string,
	allowedOrigins []string,
	enableDevPlanSwitcher bool,
	readyCheck func(ctx context.Context) error,
	logger *slog.Logger,
) chi.Router {
	r := chi.NewRouter()

	// Global middleware chain.
	r.Use(middleware.RequestID)
	r.Use(middleware.Recovery(logger))
	r.Use(middleware.SecurityHeaders)
	r.Use(middleware.CORS(allowedOrigins))
	r.Use(middleware.RateLimit(100, time.Minute))
	r.Use(middleware.MaxBodyBytes)
	r.Use(middleware.Logging(logger))

	// Health check endpoints (no auth required).
	r.Get("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	})
	// Readiness probes the DB so the orchestrator stops routing traffic to an
	// instance that lost its pool.
	r.Get("/readyz", func(w http.ResponseWriter, req *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		ctx, cancel := context.WithTimeout(req.Context(), 2*time.Second)
		defer cancel()
		if err := readyCheck(ctx); err != nil {
			logger.Error("readiness check failed", slog.String("error", err.Error()))
			w.WriteHeader(http.StatusServiceUnavailable)
			_, _ = w.Write([]byte(`{"status":"unavailable"}`))
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	})

	// Keep /health as alias for backwards compatibility.
	r.Get("/health", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	})

	// Public shared trips (no auth) — the share/landing pages. Tighter rate
	// limit: unauthenticated surface reachable by anyone with a link.
	r.Route("/public/trips", func(r chi.Router) {
		r.Use(middleware.RateLimit(30, time.Minute))
		r.Get("/{token}", tripH.PublicJSON)
		r.With(middleware.PublicPageCSP).Get("/{token}/view", tripH.PublicView)
	})

	// Legal pages (no auth) — linked from App Store Connect and the app.
	r.Route("/legal", func(r chi.Router) {
		r.Use(middleware.PublicPageCSP)
		r.Get("/privacy", legalH.Privacy)
		r.Get("/terms", legalH.Terms)
	})

	// Provider webhooks (no JWT — authenticated by a shared secret in the
	// handler). Strict rate limit: RevenueCat sends single events, not bursts.
	r.With(middleware.RateLimit(20, time.Minute)).
		Post("/api/v1/webhooks/revenuecat", webhookH.RevenueCat)

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
					r.Put("/{userId}/permissions", boatH.SetMemberPermissions)
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

				r.Get("/readiness", readinessH.Get)
				r.Get("/cost-analytics", costH.Get)
				r.Get("/anomalies", anomalyH.List)
				r.Get("/expense-splits-summary", sharedH.ListSplitSummary)

				r.Route("/maintenance", func(r chi.Router) {
					r.Get("/", maintenanceH.ListLogs)
					r.Post("/", maintenanceH.CreateLog)
					// Static /tasks resolves before the /{logId} param in chi.
					r.Route("/tasks", func(r chi.Router) {
						r.Get("/", maintenanceH.ListTasks)
						r.Post("/", maintenanceH.CreateTask)
						r.Put("/{taskId}", maintenanceH.UpdateTask)
						r.Delete("/{taskId}", maintenanceH.DeleteTask)
					})
					r.Put("/{logId}", maintenanceH.UpdateLog)
					r.Delete("/{logId}", maintenanceH.DeleteLog)
				})

				r.Route("/expenses", func(r chi.Router) {
					r.Get("/", maintenanceH.ListExpenses)
					r.Post("/", maintenanceH.CreateExpense)
					r.Get("/summary", maintenanceH.ExpenseSummary)
					r.Put("/{expenseId}", maintenanceH.UpdateExpense)
					r.Delete("/{expenseId}", maintenanceH.DeleteExpense)
					r.Get("/{expenseId}/splits", sharedH.ListSplits)
					r.Put("/{expenseId}/splits", sharedH.SetSplits)
					r.Put("/{expenseId}/splits/{splitId}/settle", sharedH.SettleSplit)
				})

				r.Route("/bookings", func(r chi.Router) {
					r.Get("/", sharedH.ListBookings)
					r.Post("/", sharedH.CreateBooking)
					r.Delete("/{bookingId}", sharedH.DeleteBooking)
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
			// Dev-only plan switcher. In production the plan is driven solely by
			// the RevenueCat webhook, so this route is not registered.
			if enableDevPlanSwitcher {
				r.Put("/plan", profileH.UpdatePlan)
			}
		})
	})

	return r
}
