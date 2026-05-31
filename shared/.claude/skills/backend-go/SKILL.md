# SKILL: Backend — Go · v2026.11
> Load when: building Go services, REST/gRPC APIs, or performance-critical backend components in Go.
> Covers: project structure, HTTP (Chi/Gin/Fiber), gRPC, Postgres (pgx), testing, Docker, common patterns

## DETECT FIRST
```bash
ls go.mod go.sum 2>/dev/null && cat go.mod | head -20
cat go.mod | grep -E "chi|gin|fiber|echo|gorilla|grpc|pgx|sqlc|ent|gorm|zerolog|zap|slog"
find . -name "*.go" -maxdepth 3 | head -10
ls cmd/ internal/ pkg/ api/ 2>/dev/null
```

---

## PROJECT STRUCTURE — Standard Go layout

```
myservice/
├── cmd/
│   └── server/
│       └── main.go          ← entry point only, wire dependencies here
├── internal/
│   ├── handler/             ← HTTP/gRPC handlers (thin — delegate to service)
│   ├── service/             ← business logic
│   ├── repository/          ← DB access (interface + impl)
│   ├── domain/              ← types, entities, errors (no imports from internal/)
│   └── middleware/          ← auth, logging, rate limit
├── pkg/                     ← importable by external packages (keep small)
├── migrations/              ← SQL migration files
├── api/                     ← OpenAPI specs, proto files
├── Dockerfile
├── docker-compose.yml
└── Makefile
```

---

## HTTP SERVER — Chi (lightweight, idiomatic)

```go
// cmd/server/main.go
package main

import (
    "context"
    "log/slog"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/go-chi/chi/v5"
    "github.com/go-chi/chi/v5/middleware"
    "github.com/jackc/pgx/v5/pgxpool"
)

func main() {
    logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
    slog.SetDefault(logger)

    pool, err := pgxpool.New(context.Background(), mustEnv("DATABASE_URL"))
    if err != nil {
        slog.Error("failed to connect to database", "err", err)
        os.Exit(1)
    }
    defer pool.Close()

    r := chi.NewRouter()
    r.Use(middleware.RequestID)
    r.Use(middleware.RealIP)
    r.Use(middleware.Logger)
    r.Use(middleware.Recoverer)
    r.Use(middleware.Timeout(30 * time.Second))

    // Mount routes
    userHandler := handler.NewUserHandler(service.NewUserService(repository.NewUserRepo(pool)))
    r.Route("/api/v1", func(r chi.Router) {
        r.Use(authMiddleware)
        r.Mount("/users", userHandler.Routes())
    })
    r.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
    })

    srv := &http.Server{
        Addr:         ":" + getEnv("PORT", "8080"),
        Handler:      r,
        ReadTimeout:  15 * time.Second,
        WriteTimeout: 15 * time.Second,
        IdleTimeout:  60 * time.Second,
    }

    // Graceful shutdown
    go func() {
        slog.Info("server starting", "addr", srv.Addr)
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            slog.Error("server error", "err", err)
            os.Exit(1)
        }
    }()

    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()
    if err := srv.Shutdown(ctx); err != nil {
        slog.Error("server forced to shutdown", "err", err)
    }
}

func mustEnv(key string) string {
    v := os.Getenv(key)
    if v == "" { panic("required env var missing: " + key) }
    return v
}
func getEnv(key, fallback string) string {
    if v := os.Getenv(key); v != "" { return v }
    return fallback
}
```

---

## HANDLER — Thin, delegate to service

```go
// internal/handler/user.go
package handler

import (
    "encoding/json"
    "errors"
    "net/http"

    "github.com/go-chi/chi/v5"
    "myservice/internal/domain"
    "myservice/internal/service"
)

type UserHandler struct {
    svc service.UserService
}

func NewUserHandler(svc service.UserService) *UserHandler {
    return &UserHandler{svc: svc}
}

func (h *UserHandler) Routes() chi.Router {
    r := chi.NewRouter()
    r.Get("/{id}", h.GetUser)
    r.Post("/", h.CreateUser)
    return r
}

func (h *UserHandler) GetUser(w http.ResponseWriter, r *http.Request) {
    id := chi.URLParam(r, "id")
    user, err := h.svc.GetByID(r.Context(), id)
    if err != nil {
        if errors.Is(err, domain.ErrNotFound) {
            writeError(w, http.StatusNotFound, "user not found")
            return
        }
        writeError(w, http.StatusInternalServerError, "internal error")
        return
    }
    writeJSON(w, http.StatusOK, user)
}

func (h *UserHandler) CreateUser(w http.ResponseWriter, r *http.Request) {
    var req domain.CreateUserRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        writeError(w, http.StatusBadRequest, "invalid request body")
        return
    }
    if err := req.Validate(); err != nil {
        writeError(w, http.StatusUnprocessableEntity, err.Error())
        return
    }
    user, err := h.svc.Create(r.Context(), req)
    if err != nil {
        if errors.Is(err, domain.ErrConflict) {
            writeError(w, http.StatusConflict, "user already exists")
            return
        }
        writeError(w, http.StatusInternalServerError, "internal error")
        return
    }
    writeJSON(w, http.StatusCreated, user)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
    writeJSON(w, status, map[string]string{"error": msg})
}
```

---

## REPOSITORY — pgx (avoid ORM for complex queries)

```go
// internal/repository/user.go
package repository

import (
    "context"
    "errors"

    "github.com/jackc/pgx/v5"
    "github.com/jackc/pgx/v5/pgxpool"
    "myservice/internal/domain"
)

type UserRepo interface {
    GetByID(ctx context.Context, id string) (*domain.User, error)
    Create(ctx context.Context, u domain.CreateUserRequest) (*domain.User, error)
}

type pgUserRepo struct {
    db *pgxpool.Pool
}

func NewUserRepo(db *pgxpool.Pool) UserRepo {
    return &pgUserRepo{db: db}
}

func (r *pgUserRepo) GetByID(ctx context.Context, id string) (*domain.User, error) {
    var u domain.User
    err := r.db.QueryRow(ctx,
        `SELECT id, email, created_at FROM users WHERE id = $1`,
        id,
    ).Scan(&u.ID, &u.Email, &u.CreatedAt)
    if err != nil {
        if errors.Is(err, pgx.ErrNoRows) {
            return nil, domain.ErrNotFound
        }
        return nil, err
    }
    return &u, nil
}

func (r *pgUserRepo) Create(ctx context.Context, req domain.CreateUserRequest) (*domain.User, error) {
    var u domain.User
    err := r.db.QueryRow(ctx,
        `INSERT INTO users (email, password_hash) VALUES ($1, $2)
         RETURNING id, email, created_at`,
        req.Email, req.PasswordHash,
    ).Scan(&u.ID, &u.Email, &u.CreatedAt)
    if err != nil {
        if isPgUniqueViolation(err) {
            return nil, domain.ErrConflict
        }
        return nil, err
    }
    return &u, nil
}

// Check Postgres error code
func isPgUniqueViolation(err error) bool {
    var pgErr *pgconn.PgError
    return errors.As(err, &pgErr) && pgErr.Code == "23505"
}
```

---

## DOMAIN ERRORS — typed, sentinel

```go
// internal/domain/errors.go
package domain

import "errors"

var (
    ErrNotFound    = errors.New("not found")
    ErrConflict    = errors.New("conflict")
    ErrUnauthorized = errors.New("unauthorized")
    ErrInvalidInput = errors.New("invalid input")
)
```

---

## TESTING — table-driven + testcontainers

```go
// internal/handler/user_test.go
package handler_test

import (
    "bytes"
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "testing"

    "myservice/internal/domain"
    "myservice/internal/handler"
    "myservice/internal/service/mock"
)

func TestGetUser(t *testing.T) {
    tests := []struct {
        name       string
        id         string
        mockReturn *domain.User
        mockErr    error
        wantStatus int
    }{
        {
            name:       "found",
            id:         "user-1",
            mockReturn: &domain.User{ID: "user-1", Email: "a@b.com"},
            wantStatus: http.StatusOK,
        },
        {
            name:       "not found",
            id:         "missing",
            mockErr:    domain.ErrNotFound,
            wantStatus: http.StatusNotFound,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            svc := mock.NewUserService(t)
            svc.On("GetByID", mock.Anything, tt.id).Return(tt.mockReturn, tt.mockErr)

            h := handler.NewUserHandler(svc)
            req := httptest.NewRequest(http.MethodGet, "/"+tt.id, nil)
            rec := httptest.NewRecorder()
            h.Routes().ServeHTTP(rec, req)

            if rec.Code != tt.wantStatus {
                t.Errorf("status = %d, want %d", rec.Code, tt.wantStatus)
            }
        })
    }
}
```

```bash
# Integration test with real Postgres (testcontainers-go)
# See: testcontainers-go.github.io
go test ./... -v -race
go test ./... -coverprofile=coverage.out && go tool cover -html=coverage.out
```

---

## MAKEFILE

```makefile
.PHONY: run build test lint migrate

run:
	go run ./cmd/server/

build:
	go build -ldflags="-s -w" -o bin/server ./cmd/server/

test:
	go test ./... -race -coverprofile=coverage.out

lint:
	golangci-lint run ./...

migrate:
	goose -dir migrations postgres "$(DATABASE_URL)" up

generate:
	go generate ./...        # sqlc generate, mockery, etc.
```

---

## DOCKERFILE

```dockerfile
# Multi-stage: builder → minimal runtime
FROM golang:1.23-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o server ./cmd/server/

FROM gcr.io/distroless/static-debian12
COPY --from=builder /app/server /server
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/server"]
```

---

## COMMON PATTERNS

```go
// Context deadline — always propagate, never ignore
func (s *userService) GetByID(ctx context.Context, id string) (*domain.User, error) {
    // pgx, http clients, etc. all respect ctx — pass it everywhere
    return s.repo.GetByID(ctx, id)
}

// Never log sensitive data
slog.Info("user.created", "user_id", user.ID) // ✅
slog.Info("user.created", "user", user)        // ❌ logs email/hash

// Prefer explicit nil check over empty struct
if user == nil { return domain.ErrNotFound }

// Use slog structured logging (stdlib Go 1.21+)
slog.InfoContext(ctx, "operation.complete", "duration_ms", time.Since(start).Milliseconds())
```
