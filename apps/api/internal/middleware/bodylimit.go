package middleware

import (
	"net/http"
	"strings"
)

const (
	// defaultBodyLimit caps normal API request bodies.
	defaultBodyLimit = 1 << 20 // 1 MiB
	// tracksBodyLimit allows the GPS batch upload that flushes a full trip's
	// track points on completion (a long passage can exceed 1 MiB of JSON).
	tracksBodyLimit = 8 << 20 // 8 MiB
)

// MaxBodyBytes wraps every request body in http.MaxBytesReader so a client
// cannot stream an unbounded payload into the JSON decoders. Reads past the
// limit make the decoder fail and the connection close.
func MaxBodyBytes(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Body != nil {
			limit := int64(defaultBodyLimit)
			if r.Method == http.MethodPost && strings.HasSuffix(r.URL.Path, "/tracks") {
				limit = tracksBodyLimit
			}
			r.Body = http.MaxBytesReader(w, r.Body, limit)
		}
		next.ServeHTTP(w, r)
	})
}
