## Build stage
FROM golang:1.26-alpine AS builder

RUN apk add --no-cache git ca-certificates

WORKDIR /app

# Copy dependency files first for better caching.
COPY go.mod go.sum ./
RUN go mod download

# Copy source code and build.
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o /api ./cmd/server

## Runtime stage
FROM gcr.io/distroless/static-debian12

COPY --from=builder /api /api

EXPOSE 8080

ENTRYPOINT ["/api"]
