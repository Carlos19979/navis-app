package service

import (
	"context"
	"fmt"

	"github.com/Carlos19979/navis-app/apps/api/internal/domain"
	"github.com/Carlos19979/navis-app/apps/api/internal/port"
)

// MaintenanceService handles boat maintenance logs and expenses.
type MaintenanceService struct {
	maint port.MaintenanceRepository
	exp   port.ExpenseRepository
	boats port.BoatRepository
}

// NewMaintenanceService creates a new MaintenanceService.
func NewMaintenanceService(maint port.MaintenanceRepository, exp port.ExpenseRepository, boats port.BoatRepository) *MaintenanceService {
	return &MaintenanceService{maint: maint, exp: exp, boats: boats}
}

// assertBoat verifies the user owns the boat (for writes).
func (s *MaintenanceService) assertBoat(ctx context.Context, userID, boatID string) error {
	if _, err := s.boats.GetByID(ctx, userID, boatID); err != nil {
		return err
	}
	return nil
}

// boatForRead verifies the user owns or has shared access to the boat and
// returns the boat (so reads use the owner's scope).
func (s *MaintenanceService) boatForRead(ctx context.Context, userID, boatID string) (*domain.Boat, error) {
	return s.boats.GetByIDAccessible(ctx, userID, boatID)
}

// AddLog records a maintenance entry.
func (s *MaintenanceService) AddLog(ctx context.Context, log *domain.MaintenanceLog) (*domain.MaintenanceLog, error) {
	if log.Type == "" {
		return nil, &domain.ValidationError{Field: "type", Message: "type is required"}
	}
	if err := s.assertBoat(ctx, log.UserID, log.BoatID); err != nil {
		return nil, fmt.Errorf("add maintenance: %w", err)
	}
	return s.maint.Create(ctx, log)
}

// ListLogs returns a boat's maintenance logs (owner or shared member).
func (s *MaintenanceService) ListLogs(ctx context.Context, userID, boatID string) ([]domain.MaintenanceLog, error) {
	boat, err := s.boatForRead(ctx, userID, boatID)
	if err != nil {
		return nil, fmt.Errorf("list maintenance: %w", err)
	}
	return s.maint.ListByBoat(ctx, boat.UserID, boatID)
}

// DeleteLog removes a maintenance log.
func (s *MaintenanceService) DeleteLog(ctx context.Context, userID, id string) error {
	return s.maint.Delete(ctx, userID, id)
}

// AddExpense records an expense.
func (s *MaintenanceService) AddExpense(ctx context.Context, e *domain.Expense) (*domain.Expense, error) {
	if e.Category == "" {
		return nil, &domain.ValidationError{Field: "category", Message: "category is required"}
	}
	if err := s.assertBoat(ctx, e.UserID, e.BoatID); err != nil {
		return nil, fmt.Errorf("add expense: %w", err)
	}
	return s.exp.Create(ctx, e)
}

// ListExpenses returns a boat's expenses (owner or shared member).
func (s *MaintenanceService) ListExpenses(ctx context.Context, userID, boatID string) ([]domain.Expense, error) {
	boat, err := s.boatForRead(ctx, userID, boatID)
	if err != nil {
		return nil, fmt.Errorf("list expenses: %w", err)
	}
	return s.exp.ListByBoat(ctx, boat.UserID, boatID)
}

// DeleteExpense removes an expense.
func (s *MaintenanceService) DeleteExpense(ctx context.Context, userID, id string) error {
	return s.exp.Delete(ctx, userID, id)
}

// ExpenseTotals returns summed expenses per category (owner or shared member).
func (s *MaintenanceService) ExpenseTotals(ctx context.Context, userID, boatID string) (map[string]float64, error) {
	boat, err := s.boatForRead(ctx, userID, boatID)
	if err != nil {
		return nil, fmt.Errorf("expense totals: %w", err)
	}
	return s.exp.TotalsByCategory(ctx, boat.UserID, boatID)
}
