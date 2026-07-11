package middleware

import (
	"net"
	"net/http"
	"strings"
	"sync"
	"time"
)

type visitor struct {
	count     int
	windowEnd time.Time
}

// ClientIP resolves the caller's IP address. Behind the production reverse
// proxy (Railway) the client IP is the first hop of X-Forwarded-For; locally
// it falls back to RemoteAddr with the port stripped, so one machine is one
// bucket instead of one bucket per TCP connection.
func ClientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		first, _, _ := strings.Cut(xff, ",")
		if ip := strings.TrimSpace(first); ip != "" {
			return ip
		}
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

// RateLimit returns middleware that limits requests per client IP within a
// window.
func RateLimit(maxRequests int, window time.Duration) func(http.Handler) http.Handler {
	var mu sync.Mutex
	visitors := make(map[string]*visitor)

	// Cleanup old entries periodically.
	go func() {
		for {
			time.Sleep(window)
			mu.Lock()
			now := time.Now()
			for ip, v := range visitors {
				if now.After(v.windowEnd) {
					delete(visitors, ip)
				}
			}
			mu.Unlock()
		}
	}()

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ip := ClientIP(r)

			mu.Lock()
			v, exists := visitors[ip]
			now := time.Now()

			if !exists || now.After(v.windowEnd) {
				visitors[ip] = &visitor{count: 1, windowEnd: now.Add(window)}
				mu.Unlock()
				next.ServeHTTP(w, r)
				return
			}

			v.count++
			if v.count > maxRequests {
				mu.Unlock()
				w.Header().Set("Content-Type", "application/json")
				w.Header().Set("Retry-After", v.windowEnd.Sub(now).String())
				w.WriteHeader(http.StatusTooManyRequests)
				_, _ = w.Write([]byte(`{"error":{"message":"rate limit exceeded","code":"RATE_LIMITED"}}`))
				return
			}

			mu.Unlock()
			next.ServeHTTP(w, r)
		})
	}
}
