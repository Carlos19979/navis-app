package middleware

import (
	"net/http"
	"sync"
	"time"
)

type visitor struct {
	count     int
	windowEnd time.Time
}

// RateLimit returns middleware that limits requests per IP within a window.
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
			ip := r.RemoteAddr

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
