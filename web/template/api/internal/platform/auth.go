package platform

import (
	"context"
	"net/http"
	"strings"

	"github.com/getkin/kin-openapi/openapi3"
	"github.com/getkin/kin-openapi/openapi3filter"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	nethttpmiddleware "github.com/oapi-codegen/nethttp-middleware"
)

type ctxKey int

const userIDKey ctxKey = iota

// UserIDFrom はミドルウェアが載せたユーザー ID を取り出す。
func UserIDFrom(ctx context.Context) (uuid.UUID, bool) {
	id, ok := ctx.Value(userIDKey).(uuid.UUID)
	return id, ok
}

// OpenAPIValidator はリクエストを OpenAPI スキーマで検証する。
// handler 側で入力を再検証しないこと。
func OpenAPIValidator(getSwagger func() (*openapi3.T, error)) func(http.Handler) http.Handler {
	spec, err := getSwagger()
	if err != nil {
		panic("load openapi spec: " + err.Error())
	}
	spec.Servers = nil // ホスト検証はしない
	return nethttpmiddleware.OapiRequestValidatorWithOptions(spec, &nethttpmiddleware.Options{
		Options: openapi3filter.Options{
			// 認証は Auth ミドルウェアで行うので、ここでは security の検証を素通しする
			AuthenticationFunc: func(context.Context, *openapi3filter.AuthenticationInput) error { return nil },
		},
	})
}

// Auth は Bearer JWT を検証してユーザー ID を context に載せる。
// security: [] のエンドポイントは OpenAPI 側で宣言されているので、
// 生成コードのルートに合わせて除外リストを持つ。
func Auth(signingKey string) func(http.Handler) http.Handler {
	public := map[string]bool{"/healthz": true, "/auth/token": true, "/auth/refresh": true}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if public[r.URL.Path] {
				next.ServeHTTP(w, r)
				return
			}
			raw := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
			if raw == "" {
				WriteProblem(w, http.StatusUnauthorized, "missing bearer token")
				return
			}
			claims := &jwt.RegisteredClaims{}
			tok, err := jwt.ParseWithClaims(raw, claims, func(*jwt.Token) (any, error) { return []byte(signingKey), nil },
				jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}))
			if err != nil || !tok.Valid {
				WriteProblem(w, http.StatusUnauthorized, "invalid token")
				return
			}
			uid, err := uuid.Parse(claims.Subject)
			if err != nil {
				WriteProblem(w, http.StatusUnauthorized, "invalid subject")
				return
			}
			next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), userIDKey, uid)))
		})
	}
}
