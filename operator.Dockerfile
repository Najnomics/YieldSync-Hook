# YieldSync Operator Dockerfile
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make gcc musl-dev

# Set working directory
WORKDIR /app

# Copy go mod files
COPY operator/go.mod operator/go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY operator/ ./

# Build the operator
RUN CGO_ENABLED=1 GOOS=linux go build -a -installsuffix cgo -o operator ./cmd

# Final stage
FROM alpine:latest

# Install runtime dependencies
RUN apk --no-cache add ca-certificates tzdata

# Create non-root user
RUN adduser -D -s /bin/sh operator

# Set working directory
WORKDIR /app

# Copy binary from builder stage
COPY --from=builder /app/operator .

# Copy configuration files
COPY operator/config-files/ ./config-files/

# Create directories for keys and data
RUN mkdir -p keys data && chown -R operator:operator /app

# Switch to non-root user
USER operator

# Expose ports
EXPOSE 8080 8081

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Run the operator
CMD ["./operator", "--config", "config-files/operator.yaml"]
