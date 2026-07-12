package domain

// ReadinessStatus is a boat's overall go/no-go signal.
type ReadinessStatus string

// ReadinessStatus values.
const (
	ReadinessReady     ReadinessStatus = "ready"
	ReadinessAttention ReadinessStatus = "attention"
	ReadinessNotReady  ReadinessStatus = "not_ready"
)

// Readiness category keys.
const (
	ReadinessCatDocuments   = "documents"
	ReadinessCatSafetyGear  = "safety_gear"
	ReadinessCatMaintenance = "maintenance"
)

// ReadinessCategory summarizes one group of checks.
type ReadinessCategory struct {
	Key      string
	Status   ReadinessStatus
	Total    int
	Expired  int
	Critical int
	Warning  int
	OK       int
}

// ReadinessItem is a single thing needing attention. The client localizes it
// from Ref (a document type or "engine_service") + Days.
type ReadinessItem struct {
	Category string
	Ref      string
	Status   ReadinessStatus
	Days     int // days until due; negative = overdue
}

// Readiness is a boat's overall "ready to sail" summary.
type Readiness struct {
	Score      int // 0-100
	Status     ReadinessStatus
	Full       bool // false => documents-only view (Free plan)
	Categories []ReadinessCategory
	Attention  []ReadinessItem
}

// SafetyGearTypes are the document types that represent on-board safety
// equipment (as opposed to paperwork like insurance/licenses).
var SafetyGearTypes = map[DocumentType]bool{
	DocumentTypeLifeRaft:     true,
	DocumentTypeExtinguisher: true,
	DocumentTypeFlares:       true,
	DocumentTypeFirstAid:     true,
}
