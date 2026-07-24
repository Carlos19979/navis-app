package moderation

import "testing"

func TestContains(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name    string
		fields  []string
		wantBad bool
	}{
		{"clean text", []string{"Club Náutico de Valencia", "Regata de primavera"}, false},
		{"banned ES word", []string{"Grupo de putas"}, true},
		{"banned EN word", []string{"fucking sailors"}, true},
		{"accented folds to banned", []string{"coño marinero"}, true},
		{"case insensitive", []string{"PUTA madre"}, true},
		{"whole-word only, no substring false positive", []string{"Assemble the crew at Scunthorpe"}, false},
		{"banned term across fields", []string{"Club náutico", "descripción con mierda"}, true},
		{"empty", []string{"", ""}, false},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			_, bad := Contains(tc.fields...)
			if bad != tc.wantBad {
				t.Fatalf("Contains(%q) bad = %v, want %v", tc.fields, bad, tc.wantBad)
			}
		})
	}
}
