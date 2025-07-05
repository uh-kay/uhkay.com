FROM golang:1.24.4-alpine AS builder

# Set working directory
WORKDIR /app

# Copy go.mod and go.sum files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy the entire project
COPY . .

# Build
RUN go build -o main .

# Use a smaller image for the final app
FROM alpine:latest

# Set working directory
WORKDIR /app

# Copy the binary from the builder stage
COPY --from=builder /app/main .

# Expose the port the server will run on
EXPOSE 8080

# Run the binary
CMD ["./main"]
