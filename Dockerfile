# Stage 1: Build the Go binary
FROM golang:1.25-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make

# Set working directory
WORKDIR /build

# Copy go mod files first for better caching
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build static binary (auto-detects architecture)
RUN CGO_ENABLED=0 go build \
    --ldflags '-w -s -extldflags "-static"' \
    -o cloudflare_exporter .

# Stage 2: Create minimal runtime image
FROM alpine:latest

# Install CA certificates for HTTPS requests
RUN apk --no-cache add ca-certificates tzdata && \
    addgroup -g 1000 exporter && \
    adduser -D -u 1000 -G exporter exporter

# Copy binary from builder
COPY --from=builder /build/cloudflare_exporter /usr/local/bin/cloudflare_exporter

# Use non-root user
USER exporter

# Expose metrics port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/cloudflare_exporter"]

# Labels
LABEL org.opencontainers.image.title="Cloudflare Prometheus Exporter" \
      org.opencontainers.image.description="Prometheus exporter for Cloudflare analytics and metrics" \
      org.opencontainers.image.source="https://github.com/dario-fernandez-osanasalud/cloudflare-exporter" \
      org.opencontainers.image.licenses="MIT"
