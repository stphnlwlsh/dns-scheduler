# Build stage
FROM golang:1.25-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the server binary
# CGO_ENABLED=0 for static binary (works in distroless)
# -ldflags="-w -s" strips debug info to reduce size
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-w -s" \
    -o dns-scheduler \
    function.go

# Runtime stage
FROM debian:12-slim

# Install minimal runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create nonroot user
RUN useradd -u 65532 -r -s /sbin/nologin nonroot

# Copy timezone data
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy the binary from builder
COPY --from=builder /build/dns-scheduler /app/dns-scheduler

# Use nonroot user
USER nonroot:nonroot

# Set working directory
WORKDIR /app

# Expose port
EXPOSE 8080

# Run the server
ENTRYPOINT ["/app/dns-scheduler"]
