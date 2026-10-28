package example

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
)

// Example はドメイン型。生成コードの型（db.Example / api.Example）を外に漏らさない。
type Example struct {
	ID        uuid.UUID
	Name      string
	CreatedAt time.Time
}

// Repository は service が必要とする操作だけを宣言する（呼ぶ側に interface）。
type Repository interface {
	List(ctx context.Context, limit int32, after *time.Time) ([]Example, error)
	Get(ctx context.Context, id uuid.UUID) (Example, error)
	Create(ctx context.Context, name string) (Example, error)
}

// Service にビジネスロジックを置く。HTTP も SQL も知らない。
type Service struct{ repo Repository }

func NewService(repo Repository) *Service { return &Service{repo: repo} }

func (s *Service) List(ctx context.Context, limit int32, after *time.Time) ([]Example, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	return s.repo.List(ctx, limit, after)
}

func (s *Service) Get(ctx context.Context, id uuid.UUID) (Example, error) {
	return s.repo.Get(ctx, id)
}

func (s *Service) Create(ctx context.Context, name string) (Example, error) {
	// 入力の形式検証は OpenAPI バリデータが済ませている。ここは業務ルールだけ。
	return s.repo.Create(ctx, strings.TrimSpace(name))
}
