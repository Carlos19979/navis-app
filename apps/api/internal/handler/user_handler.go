package handler

import (
	"net/http"

	"github.com/Carlos19979/navis-app/apps/api/internal/service"
)

// UserHandler handles GDPR data export and account deletion.
type UserHandler struct {
	users *service.UserService
}

// NewUserHandler creates a UserHandler backed by the user service.
func NewUserHandler(users *service.UserService) *UserHandler {
	return &UserHandler{users: users}
}

// ExportData returns all user data as a JSON download.
func (h *UserHandler) ExportData(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	export, err := h.users.ExportData(r.Context(), userID)
	if err != nil {
		MapDomainError(w, err)
		return
	}

	w.Header().Set("Content-Disposition", "attachment; filename=navis-export.json")
	JSON(w, http.StatusOK, export)
}

// DeleteAccount permanently deletes the user's files, data, and auth account.
func (h *UserHandler) DeleteAccount(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireUserID(w, r)
	if !ok {
		return
	}

	if err := h.users.DeleteAccount(r.Context(), userID); err != nil {
		MapDomainError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
