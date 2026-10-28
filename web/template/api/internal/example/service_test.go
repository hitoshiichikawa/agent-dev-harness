package example

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
)

// service のテストは repo を interface で差し替える（ここだけはメモリ実装でよい）。
// repo 自体のテストは実 Postgres（testcontainers）で repo_test.go に書く。
type memRepo struct{ items []Example }

func (m *memRepo) List(_ context.Context, limit int32, _ *time.Time) ([]Example, error) {
	if int(limit) < len(m.items) {
		return m.items[:limit], nil
	}
	return m.items, nil
}
func (m *memRepo) Get(_ context.Context, id uuid.UUID) (Example, error) {
	for _, it := range m.items {
		if it.ID == id {
			return it, nil
		}
	}
	return Example{}, errNotFoundForTest
}
func (m *memRepo) Create(_ context.Context, name string) (Example, error) {
	e := Example{ID: uuid.New(), Name: name, CreatedAt: time.Now()}
	m.items = append(m.items, e)
	return e, nil
}

var errNotFoundForTest = context.Canceled

func TestService_Create_TrimsName(t *testing.T) {
	svc := NewService(&memRepo{})
	got, err := svc.Create(context.Background(), "  hello  ")
	if err != nil {
		t.Fatal(err)
	}
	if got.Name != "hello" {
		t.Errorf("want trimmed name, got %q", got.Name)
	}
}

func TestService_List_ClampsLimit(t *testing.T) {
	repo := &memRepo{}
	for range 30 {
		_, _ = repo.Create(context.Background(), "x")
	}
	svc := NewService(repo)
	got, err := svc.List(context.Background(), 0, nil)
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 20 {
		t.Errorf("want default limit 20, got %d", len(got))
	}
}
