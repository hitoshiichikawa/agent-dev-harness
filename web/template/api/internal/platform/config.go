// Package platform は横断的関心事（設定、DB 接続、ログ、認証ミドルウェア）を置く。
// ドメインロジックは置かない。
package platform

import (
	"fmt"
	"os"
	"strings"
	"time"
)

// Config は環境変数からのみ読む。デフォルト値はローカル開発用。
type Config struct {
	Env             string
	Port            string
	DatabaseURL     string
	CORSOrigins     []string
	AuthSigningKey  string
	AccessTokenTTL  time.Duration
	RefreshTokenTTL time.Duration
}

func LoadConfig() (Config, error) {
	cfg := Config{
		Env:            getenv("APP_ENV", "local"),
		Port:           getenv("APP_PORT", "8080"),
		DatabaseURL:    os.Getenv("DATABASE_URL"),
		CORSOrigins:    strings.Split(getenv("CORS_ORIGINS", "http://localhost:5173"), ","),
		AuthSigningKey: os.Getenv("AUTH_SIGNING_KEY"),
	}
	if cfg.DatabaseURL == "" {
		return cfg, fmt.Errorf("DATABASE_URL is required")
	}
	if cfg.AuthSigningKey == "" {
		return cfg, fmt.Errorf("AUTH_SIGNING_KEY is required")
	}
	var err error
	if cfg.AccessTokenTTL, err = time.ParseDuration(getenv("AUTH_ACCESS_TOKEN_TTL", "15m")); err != nil {
		return cfg, fmt.Errorf("AUTH_ACCESS_TOKEN_TTL: %w", err)
	}
	if cfg.RefreshTokenTTL, err = time.ParseDuration(getenv("AUTH_REFRESH_TOKEN_TTL", "720h")); err != nil {
		return cfg, fmt.Errorf("AUTH_REFRESH_TOKEN_TTL: %w", err)
	}
	return cfg, nil
}

func getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
