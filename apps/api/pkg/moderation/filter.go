// Package moderation provides a lightweight, dependency-free objectionable-
// content filter used to reject user-generated text (group and event names /
// descriptions) at creation time. It is one of the three pillars App Store
// Review Guideline 1.2 requires for user-generated content, alongside user
// reporting and blocking.
//
// The filter is deliberately conservative: it matches whole tokens against a
// curated block list (ES + EN), after lowercasing and stripping diacritics, so
// "Scunthorpe"-style false positives don't occur. It is not meant to be
// exhaustive — reporting + blocking cover what slips through.
package moderation

import (
	"strings"
	"unicode"
)

// bannedTerms is a curated set of slurs / severe profanity in Spanish and
// English. Kept intentionally small and high-precision; extend as needed.
var bannedTerms = map[string]struct{}{}

func init() {
	for _, t := range []string{
		// ES
		"puta", "putas", "puto", "putos", "cabron", "cabrones", "gilipollas",
		"maricon", "maricones", "mariconazo", "zorra", "polla", "coño", "cono",
		"joder", "mierda", "subnormal", "retrasado", "negrata", "sudaca",
		"maracon",
		// EN
		"fuck", "fucker", "fucking", "shit", "bitch", "cunt", "asshole",
		"nigger", "nigga", "faggot", "fag", "retard", "whore", "slut", "rape",
	} {
		bannedTerms[t] = struct{}{}
	}
}

// Contains reports whether any of the given text fields contain a banned term.
// It returns the first banned term found, or "" and false when the text is clean.
func Contains(fields ...string) (string, bool) {
	for _, f := range fields {
		for _, token := range tokenize(f) {
			if _, bad := bannedTerms[token]; bad {
				return token, true
			}
		}
	}
	return "", false
}

// tokenize lowercases, folds diacritics, and splits text into alphabetic tokens.
func tokenize(s string) []string {
	folded := strings.Map(func(r rune) rune {
		return unicode.ToLower(fold(r))
	}, s)
	return strings.FieldsFunc(folded, func(r rune) bool {
		return !unicode.IsLetter(r)
	})
}

// fold maps the accented Latin characters common in Spanish to their base form
// so "coño" and "cono" both normalise to the same token.
func fold(r rune) rune {
	switch r {
	case 'á', 'à', 'ä', 'â', 'Á', 'À', 'Ä', 'Â':
		return 'a'
	case 'é', 'è', 'ë', 'ê', 'É', 'È', 'Ë', 'Ê':
		return 'e'
	case 'í', 'ì', 'ï', 'î', 'Í', 'Ì', 'Ï', 'Î':
		return 'i'
	case 'ó', 'ò', 'ö', 'ô', 'Ó', 'Ò', 'Ö', 'Ô':
		return 'o'
	case 'ú', 'ù', 'ü', 'û', 'Ú', 'Ù', 'Ü', 'Û':
		return 'u'
	case 'ñ', 'Ñ':
		return 'n'
	default:
		return r
	}
}
