package platform

import (
	"encoding/json"
	"errors"
	"net/http"
)

// Problem は RFC 9457 Problem Details。OpenAPI の Problem スキーマと一致させる。
type Problem struct {
	Type   string       `json:"type,omitempty"`
	Title  string       `json:"title"`
	Status int          `json:"status"`
	Detail string       `json:"detail,omitempty"`
	Errors []FieldError `json:"errors,omitempty"`
}

type FieldError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
}

func WriteProblem(w http.ResponseWriter, status int, detail string) {
	w.Header().Set("Content-Type", "application/problem+json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(Problem{Title: http.StatusText(status), Status: status, Detail: detail})
}

// ドメイン共通のエラー。service が返し、handler が 1 箇所で HTTP に変換する。
var (
	ErrNotFound     = errors.New("not found")
	ErrUnauthorized = errors.New("unauthorized")
	ErrInvalid      = errors.New("invalid")
)
