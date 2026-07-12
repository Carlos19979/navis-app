package dto

import "github.com/Carlos19979/navis-app/apps/api/internal/domain"

// ReadinessCategoryResponse mirrors a domain.ReadinessCategory.
type ReadinessCategoryResponse struct {
	Key      string `json:"key"`
	Status   string `json:"status"`
	Total    int    `json:"total"`
	Expired  int    `json:"expired"`
	Critical int    `json:"critical"`
	Warning  int    `json:"warning"`
	OK       int    `json:"ok"`
}

// ReadinessItemResponse mirrors a domain.ReadinessItem.
type ReadinessItemResponse struct {
	Category string `json:"category"`
	Ref      string `json:"ref"`
	Status   string `json:"status"`
	Days     int    `json:"days"`
}

// ReadinessResponse is the boat-readiness payload.
type ReadinessResponse struct {
	Score      int                         `json:"score"`
	Status     string                      `json:"status"`
	Full       bool                        `json:"full"`
	Categories []ReadinessCategoryResponse `json:"categories"`
	Attention  []ReadinessItemResponse     `json:"attention"`
}

// ReadinessResponseFromDomain converts a domain.Readiness to a response.
func ReadinessResponseFromDomain(r *domain.Readiness) ReadinessResponse {
	cats := make([]ReadinessCategoryResponse, len(r.Categories))
	for i, c := range r.Categories {
		cats[i] = ReadinessCategoryResponse{
			Key:      c.Key,
			Status:   string(c.Status),
			Total:    c.Total,
			Expired:  c.Expired,
			Critical: c.Critical,
			Warning:  c.Warning,
			OK:       c.OK,
		}
	}
	items := make([]ReadinessItemResponse, len(r.Attention))
	for i, it := range r.Attention {
		items[i] = ReadinessItemResponse{
			Category: it.Category,
			Ref:      it.Ref,
			Status:   string(it.Status),
			Days:     it.Days,
		}
	}
	return ReadinessResponse{
		Score:      r.Score,
		Status:     string(r.Status),
		Full:       r.Full,
		Categories: cats,
		Attention:  items,
	}
}
