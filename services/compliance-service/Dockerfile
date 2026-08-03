# syntax=docker/dockerfile:1

FROM golang:1.22-alpine AS builder
WORKDIR /src

RUN apk add --no-cache ca-certificates git

COPY packages/shared/middleware/go.mod packages/shared/middleware/go.sum ./packages/shared/middleware/
COPY services/compliance-service/go.mod ./services/compliance-service/

WORKDIR /src/services/compliance-service
RUN go mod download

COPY packages/shared/middleware /src/packages/shared/middleware
COPY services/compliance-service /src/services/compliance-service

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go test ./...
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /server .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /server /server

EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/server"]
