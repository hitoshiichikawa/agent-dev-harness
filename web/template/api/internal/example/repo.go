// Package example は 1 ドメインの縦割り単位。handler / service / repo を同じパッケージに置く。
// 新しいドメインはこのパッケージをコピーして作る。
package example

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	db "github.com/ORG/APP/api/internal/generated/db"
	"github.com/ORG/APP/api/internal/platform"
)

// Repo は sqlc の薄いラッパ。ドメイン型への変換と、sqlc のエラーをドメインエラーに寄せるだけ。
type Repo struct{ q *db.Queries }

func NewRepo(q *db.Queries) *Repo { return &Repo{q: q} }

func (r *Repo) List(ctx context.Context, limit int32, after *time.Time) ([]Example, error) {
	rows, err := r.q.ListExamples(ctx, db.ListExamplesParams{Limit: limit, After: after})
	if err != nil {
		return nil, fmt.Errorf("list examples: %w", err)
	}
	out := make([]Example, 0, len(rows))
	for _, row := range rows {
		out = append(out, fromRow(row.ID, row.Name, row.CreatedAt))
	}
	return out, nil
}

func (r *Repo) Get(ctx context.Context, id uuid.UUID) (Example, error) {
	row, err := r.q.GetExample(ctx, id)
	if errors.Is(err, pgx.ErrNoRows) {
		return Example{}, platform.ErrNotFound
	}
	if err != nil {
		return Example{}, fmt.Errorf("get example: %w", err)
	}
	return fromRow(row.ID, row.Name, row.CreatedAt), nil
}

func (r *Repo) Create(ctx context.Context, name string) (Example, error) {
	row, err := r.q.CreateExample(ctx, name)
	if err != nil {
		return Example{}, fmt.Errorf("create example: %w", err)
	}
	return fromRow(row.ID, row.Name, row.CreatedAt), nil
}

func fromRow(id uuid.UUID, name string, createdAt time.Time) Example {
	return Example{ID: id, Name: name, CreatedAt: createdAt}
}
