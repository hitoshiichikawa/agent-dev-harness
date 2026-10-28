package example

import (
	"context"
	"errors"
	"time"

	openapi_types "github.com/oapi-codegen/runtime/types"

	api "github.com/ORG/APP/api/internal/generated/api"
	"github.com/ORG/APP/api/internal/platform"
)

// Handler は生成された StrictServerInterface のうちこのドメインの分を実装する。
// 変換と service 呼び出しだけ。ロジックを書かない。
type Handler struct{ svc *Service }

func NewHandler(svc *Service) *Handler { return &Handler{svc: svc} }

func (h *Handler) GetHealth(context.Context, api.GetHealthRequestObject) (api.GetHealthResponseObject, error) {
	return api.GetHealth200JSONResponse{Status: api.Ok}, nil
}

func (h *Handler) ListExamples(ctx context.Context, req api.ListExamplesRequestObject) (api.ListExamplesResponseObject, error) {
	var limit int32 = 20
	if req.Params.Limit != nil {
		limit = int32(*req.Params.Limit)
	}
	var after *time.Time
	if req.Params.Cursor != nil {
		if t, err := time.Parse(time.RFC3339Nano, *req.Params.Cursor); err == nil {
			after = &t
		}
	}
	items, err := h.svc.List(ctx, limit, after)
	if err != nil {
		return nil, err
	}
	resp := api.ListExamples200JSONResponse{Items: make([]api.Example, 0, len(items))}
	for _, it := range items {
		resp.Items = append(resp.Items, toAPI(it))
	}
	if len(items) == int(limit) {
		c := items[len(items)-1].CreatedAt.Format(time.RFC3339Nano)
		resp.NextCursor = &c
	}
	return resp, nil
}

func (h *Handler) GetExample(ctx context.Context, req api.GetExampleRequestObject) (api.GetExampleResponseObject, error) {
	ex, err := h.svc.Get(ctx, req.Id)
	if errors.Is(err, platform.ErrNotFound) {
		return api.GetExample404JSONResponse{Title: "Not Found", Status: 404}, nil
	}
	if err != nil {
		return nil, err
	}
	return api.GetExample200JSONResponse(toAPI(ex)), nil
}

func (h *Handler) CreateExample(ctx context.Context, req api.CreateExampleRequestObject) (api.CreateExampleResponseObject, error) {
	ex, err := h.svc.Create(ctx, req.Body.Name)
	if err != nil {
		return nil, err
	}
	return api.CreateExample201JSONResponse(toAPI(ex)), nil
}

func toAPI(e Example) api.Example {
	return api.Example{Id: openapi_types.UUID(e.ID), Name: e.Name, CreatedAt: e.CreatedAt}
}
