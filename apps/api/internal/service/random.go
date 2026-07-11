package service

import (
	"crypto/rand"
	"fmt"
)

// codeAlphabet excludes ambiguous characters (0/O, 1/I/L) for readability.
// Shared by group invite codes and boat share codes.
const codeAlphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

// randomCode returns a random n-character human-readable code.
func randomCode(n int) (string, error) {
	buf := make([]byte, n)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("generating random code: %w", err)
	}
	for i := range buf {
		buf[i] = codeAlphabet[int(buf[i])%len(codeAlphabet)]
	}
	return string(buf), nil
}
