package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/getsentry/sentry-go"
	"github.com/joho/godotenv"

	"github.com/Carlos19979/navis-app/apps/api/internal/adapter/novu"
	"github.com/Carlos19979/navis-app/apps/api/internal/adapter/openmeteo"
	"github.com/Carlos19979/navis-app/apps/api/internal/adapter/postgres"
	"github.com/Carlos19979/navis-app/apps/api/internal/adapter/supabase"
	"github.com/Carlos19979/navis-app/apps/api/internal/config"
	"github.com/Carlos19979/navis-app/apps/api/internal/cron"
	"github.com/Carlos19979/navis-app/apps/api/internal/handler"
	"github.com/Carlos19979/navis-app/apps/api/internal/router"
	"github.com/Carlos19979/navis-app/apps/api/internal/service"
)

func main() {
	_ = godotenv.Load()

	cfg := config.Load()
	if err := cfg.Validate(); err != nil {
		fmt.Fprintf(os.Stderr, "fatal: %v\n", err)
		os.Exit(1)
	}

	// Set up structured logger.
	logLevel := slog.LevelInfo
	switch cfg.LogLevel {
	case "debug":
		logLevel = slog.LevelDebug
	case "warn":
		logLevel = slog.LevelWarn
	case "error":
		logLevel = slog.LevelError
	}

	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: logLevel,
	}))
	slog.SetDefault(logger)

	if cfg.IsProduction() && cfg.NovuAPIKey == "" {
		logger.Warn("NOVU_API_KEY is empty in production — " +
			"NO notifications (document expiry, regatta reminders) will be delivered")
	}

	// Initialize Sentry.
	if cfg.SentryDSN != "" {
		if err := sentry.Init(sentry.ClientOptions{
			Dsn:              cfg.SentryDSN,
			TracesSampleRate: 0.2,
			Environment:      cfg.AppEnv,
		}); err != nil {
			logger.Error("failed to init sentry", slog.String("error", err.Error()))
		} else {
			defer sentry.Flush(2 * time.Second)
			logger.Info("sentry initialized")
		}
	}

	// Create context that listens for interrupt signals.
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	// Connect to PostgreSQL.
	pool, err := postgres.NewPool(ctx, cfg.DatabaseURL)
	if err != nil {
		logger.Error("failed to connect to database", slog.String("error", err.Error()))
		return
	}
	defer pool.Close()
	logger.Info("connected to database")

	// Create repositories.
	boatRepo := postgres.NewBoatRepo(pool)
	docRepo := postgres.NewDocumentRepo(pool)
	tripRepo := postgres.NewTripRepo(pool)
	trackRepo := postgres.NewTripTrackRepo(pool)
	eventRepo := postgres.NewEventRepo(pool)
	interestRepo := postgres.NewEventInterestRepo(pool)
	groupRepo := postgres.NewGroupRepo(pool)
	groupMemberRepo := postgres.NewGroupMemberRepo(pool)
	participantRepo := postgres.NewTripParticipantRepo(pool)
	checklistRepo := postgres.NewTripChecklistRepo(pool)
	notifLogRepo := postgres.NewNotificationLogRepo(pool)
	portRepo := postgres.NewPortRepo(pool)
	deviceTokenRepo := postgres.NewDeviceTokenRepo(pool)
	userRepo := postgres.NewUserRepo(pool)
	sentNotifRepo := postgres.NewSentNotificationRepo(pool)
	profileRepo := postgres.NewProfileRepo(pool)
	maintenanceRepo := postgres.NewMaintenanceRepo(pool)
	maintenanceTaskRepo := postgres.NewMaintenanceTaskRepo(pool)
	expenseRepo := postgres.NewExpenseRepo(pool)
	bookingRepo := postgres.NewBookingRepo(pool)
	expenseSplitRepo := postgres.NewExpenseSplitRepo(pool)

	// Create adapters.
	weatherProvider := openmeteo.New()
	notifier := novu.New(cfg.NovuAPIKey, logger)
	notifySvc := service.NewNotifier(notifier, userRepo, logger)
	// Deliver notifications off the request path; drained on shutdown.
	notifySvc.Start()
	defer notifySvc.Stop()
	supabaseAdmin := supabase.NewAdmin(cfg.SupabaseURL, cfg.SupabaseServiceRoleKey, logger)

	// Create services.
	boatSvc := service.NewBoatService(boatRepo, profileRepo)
	docSvc := service.NewDocumentService(docRepo, boatRepo)
	tripSvc := service.NewTripService(tripRepo, trackRepo, boatRepo)
	eventSvc := service.NewEventService(eventRepo, interestRepo)
	groupSvc := service.NewGroupService(groupRepo, groupMemberRepo, profileRepo, notifySvc, postgres.NewTxManager(pool))
	profileSvc := service.NewProfileService(profileRepo, boatRepo)
	readinessSvc := service.NewReadinessService(docRepo, maintenanceRepo, maintenanceTaskRepo, boatRepo, profileRepo)
	costSvc := service.NewCostService(expenseRepo, maintenanceRepo, tripRepo, boatRepo, profileRepo)
	sharedSvc := service.NewSharedService(bookingRepo, expenseSplitRepo, expenseRepo, boatRepo, profileRepo, notifySvc)
	anomalySvc := service.NewAnomalyService(tripRepo, boatRepo, profileRepo)
	maintenanceSvc := service.NewMaintenanceService(maintenanceRepo, maintenanceTaskRepo, expenseRepo, boatRepo)
	regattaSvc := service.NewRegattaService(tripRepo, participantRepo, checklistRepo, groupMemberRepo, notifySvc)
	portSvc := service.NewPortService(portRepo)
	weatherSvc := service.NewWeatherService(weatherProvider)
	userSvc := service.NewUserService(
		supabaseAdmin, boatRepo, docRepo, tripRepo, trackRepo, participantRepo,
		checklistRepo, maintenanceRepo, expenseRepo, groupRepo, deviceTokenRepo,
		profileRepo, logger)

	// Create and start expiration checker cron.
	expirationChecker := cron.New(docRepo, notifLogRepo, profileRepo, notifier, logger)
	expirationChecker.Start()
	defer expirationChecker.Stop()

	// Create and start maintenance-due checker cron (Pro reminders).
	maintNotifLogRepo := postgres.NewMaintenanceNotificationLogRepo(pool)
	maintenanceChecker := cron.NewMaintenanceChecker(
		maintenanceSvc, maintNotifLogRepo, profileRepo, notifier, logger)
	maintenanceChecker.Start()
	defer maintenanceChecker.Stop()

	// Create and start regatta reminder / live-event notifier cron.
	regattaNotifier := cron.NewRegattaNotifier(
		tripRepo, groupMemberRepo, eventRepo, interestRepo, sentNotifRepo, notifySvc, logger)
	regattaNotifier.Start()
	defer regattaNotifier.Stop()

	// Create handlers.
	boatH := handler.NewBoatHandler(boatSvc)
	docH := handler.NewDocumentHandler(docSvc)
	tripH := handler.NewTripHandler(tripSvc)
	eventH := handler.NewEventHandler(eventSvc)
	groupH := handler.NewGroupHandler(groupSvc)
	regattaH := handler.NewRegattaHandler(regattaSvc)
	portH := handler.NewPortHandler(portSvc)
	weatherH := handler.NewWeatherHandler(weatherSvc)
	deviceH := handler.NewDeviceHandler(deviceTokenRepo, notifier)
	userH := handler.NewUserHandler(userSvc)
	profileH := handler.NewProfileHandler(profileSvc)
	maintenanceH := handler.NewMaintenanceHandler(maintenanceSvc)
	readinessH := handler.NewReadinessHandler(readinessSvc)
	costH := handler.NewCostHandler(costSvc)
	sharedH := handler.NewSharedHandler(sharedSvc)
	anomalyH := handler.NewAnomalyHandler(anomalySvc)
	webhookH := handler.NewWebhookHandler(profileSvc, cfg.RevenueCatWebhookSecret, logger)
	legalH := handler.NewLegalHandler()

	// Create router.
	jwksURL := cfg.SupabaseURL + "/auth/v1/.well-known/jwks.json"
	enableDevPlanSwitcher := cfg.AppEnv != "production"

	r := router.New(
		boatH, docH, tripH, eventH, groupH, regattaH, portH, weatherH, deviceH, userH, profileH, maintenanceH,
		readinessH,
		costH,
		sharedH,
		anomalyH,
		webhookH,
		legalH,
		cfg.SupabaseJWTSecret,
		jwksURL,
		cfg.CORSAllowedOrigins,
		enableDevPlanSwitcher,
		pool.Ping,
		logger,
	)

	// Create HTTP server.
	srv := &http.Server{
		Addr:         fmt.Sprintf(":%s", cfg.Port),
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in a goroutine.
	go func() {
		logger.Info("starting server", slog.String("addr", srv.Addr))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Error("server error", slog.String("error", err.Error()))
			os.Exit(1)
		}
	}()

	// Wait for interrupt signal.
	<-ctx.Done()
	logger.Info("shutting down server...")

	// Graceful shutdown with a 30-second deadline.
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		logger.Error("server shutdown error", slog.String("error", err.Error()))
	}

	logger.Info("server stopped gracefully")
}
