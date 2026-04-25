package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"github.com/Carlos19979/navis-app/apps/api/internal/dto"
	"github.com/Carlos19979/navis-app/apps/api/internal/middleware"
	"github.com/Carlos19979/navis-app/apps/api/internal/service"
	"github.com/Carlos19979/navis-app/apps/api/pkg/pagination"
	"github.com/Carlos19979/navis-app/apps/api/pkg/validator"
)

// DocumentHandler handles HTTP requests for document operations.
type DocumentHandler struct {
	svc *service.DocumentService
}

// NewDocumentHandler creates a new DocumentHandler.
func NewDocumentHandler(svc *service.DocumentService) *DocumentHandler {
	return &DocumentHandler{svc: svc}
}

// Create handles POST /boats/{boatId}/documents.
func (h *DocumentHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
		return
	}

	var req dto.CreateDocumentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}

	// Override BoatID from URL parameter.
	boatID := chi.URLParam(r, "boatId")
	if boatID != "" {
		req.BoatID = boatID
	}

	if errs := validator.Validate(req); errs != nil {
		ValidationError(w, errs)
		return
	}

	doc := req.ToDomain(userID)
	created, err := h.svc.Create(r.Context(), doc)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusCreated, dto.DocumentResponseFromDomain(created))
}

// GetByID handles GET /documents/{id}.
func (h *DocumentHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
		return
	}

	id := chi.URLParam(r, "id")
	doc, err := h.svc.GetByID(r.Context(), userID, id)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.DocumentResponseFromDomain(doc))
}

// ListByBoat handles GET /boats/{boatId}/documents.
func (h *DocumentHandler) ListByBoat(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
		return
	}

	boatID := chi.URLParam(r, "boatId")
	cursor, limit := pagination.ParseCursor(r)

	docs, nextCursor, err := h.svc.ListByBoat(r.Context(), userID, boatID, cursor, limit)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	var meta *Meta
	if nextCursor != "" {
		encoded := pagination.EncodeCursor(nextCursor)
		meta = &Meta{NextCursor: &encoded}
	}

	JSONWithMeta(w, http.StatusOK, dto.DocumentListResponseFromDomain(docs), meta)
}

// Update handles PUT /documents/{id}.
func (h *DocumentHandler) Update(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
		return
	}

	id := chi.URLParam(r, "id")

	var req dto.UpdateDocumentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		Error(w, http.StatusBadRequest, "invalid request body", "BAD_REQUEST")
		return
	}

	if errs := validator.Validate(req); errs != nil {
		ValidationError(w, errs)
		return
	}

	existing, err := h.svc.GetByID(r.Context(), userID, id)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	req.ApplyTo(existing)
	updated, err := h.svc.Update(r.Context(), userID, existing)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	JSON(w, http.StatusOK, dto.DocumentResponseFromDomain(updated))
}

// Delete handles DELETE /documents/{id}.
func (h *DocumentHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		Error(w, http.StatusUnauthorized, "unauthorized", "UNAUTHORIZED")
		return
	}

	id := chi.URLParam(r, "id")
	if err := h.svc.Delete(r.Context(), userID, id); err != nil {
		MapDomainError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
