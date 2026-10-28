// Package main は起動・DI・ルーター組み立てだけを担当する。ビジネスロジックを置かない。
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"

	"github.com/ORG/APP/api/internal/example"
	api "github.com/ORG/APP/api/internal/generated/api"
	db "github.com/ORG/APP/api/internal/generated/db"
	"github.com/ORG/APP/api/internal/platform"
)

func main() {
	if err := run(); err != nil {
		slog.Error("fatal", "err", err)
		os.Exit(1)
	}
}

func run() error {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	cfg, err := platform.LoadConfig()
	if err != nil {
		return err
	}
	platform.SetupLogger(cfg.Env)

	pool, err := platform.NewDBPool(ctx, cfg.DatabaseURL)
	if err != nil {
		return err
	}
	defer pool.Close()

	queries := db.New(pool)

	// --- ドメインの組み立て（interface は呼ぶ側に定義、実装はここで渡す）
	exampleSvc := example.NewService(example.NewRepo(queries))

	// --- OpenAPI 生成の StrictServerInterface を各ドメインの handler で合成する
	server := api.NewStrictHandler(&handlers{
		Example: example.NewHandler(exampleSvc),
	}, nil)

	r := chi.NewRouter()
	r.Use(middleware.RequestID, middleware.RealIP, platform.RequestLogger, middleware.Recoverer)
	r.Use(cors.Handler(cors.Options{AllowedOrigins: cfg.CORSOrigins, AllowedMethods: []string{"GET", "POST", "PUT", "PATCH", "DELETE"}, AllowedHeaders: []string{"Authorization", "Content-Type"}}))
	r.Use(platform.OpenAPIValidator(api.GetSwagger))
	r.Use(platform.Auth(cfg.AuthSigningKey))
	api.HandlerFromMux(server, r)

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           r,
		ReadHeaderTimeout: 5 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() { errCh <- srv.ListenAndServe() }()
	slog.Info("listening", "addr", srv.Addr)

	select {
	case err := <-errCh:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		return srv.Shutdown(shutdownCtx)
	}
}

// handlers は各ドメインの handler を埋め込んで StrictServerInterface を満たす。
// 新しいドメインを足すときはここに 1 行追加する。
type handlers struct {
	*example.Handler
	// *auth.Handler
}
