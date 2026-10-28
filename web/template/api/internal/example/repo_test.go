package example

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/pressly/goose/v3"
	"github.com/testcontainers/testcontainers-go/modules/postgres"

	db "github.com/ORG/APP/api/internal/generated/db"
)

// repo は実 Postgres で検証する。DB をモックしない。
func newTestDB(t *testing.T) *pgxpool.Pool {
	t.Helper()
	ctx := context.Background()
	pg, err := postgres.Run(ctx, "postgres:17-alpine",
		postgres.WithDatabase("test"), postgres.WithUsername("test"), postgres.WithPassword("test"),
		postgres.BasicWaitStrategies())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = pg.Terminate(ctx) })

	dsn, err := pg.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		t.Fatal(err)
	}
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(pool.Close)

	sqldb, err := goose.OpenDBWithDriver("pgx", dsn)
	if err != nil {
		t.Fatal(err)
	}
	defer sqldb.Close()
	if err := goose.Up(sqldb, "../../db/migrations"); err != nil {
		t.Fatal(err)
	}
	return pool
}

func TestRepo_CreateAndGet(t *testing.T) {
	if testing.Short() {
		t.Skip("needs docker")
	}
	pool := newTestDB(t)
	repo := NewRepo(db.New(pool))
	ctx := context.Background()

	created, err := repo.Create(ctx, "first")
	if err != nil {
		t.Fatal(err)
	}
	got, err := repo.Get(ctx, created.ID)
	if err != nil {
		t.Fatal(err)
	}
	if got.Name != "first" {
		t.Errorf("want first, got %q", got.Name)
	}
}
