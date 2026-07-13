---
name: config-and-secrets
description: Use when reading configuration or secrets — loading env vars, wiring a config struct, connection strings, feature flags, or anything the service needs at boot. Enforces 12-factor config from the environment, fail-fast validation at startup, no hardcoded or committed secrets, and per-environment values injected rather than branched in code.
---

# Config & secrets

A service should know at *startup* whether it can run — not discover a missing database URL at the
first request, and never fall back to an insecure default. These rules cover boot-time correctness.

## Rules

- **Config comes from the environment**, not baked into code or a committed file. Read it once at
  startup into a single typed config struct; pass that struct explicitly. Don't scatter
  `os.Getenv(...)` through the codebase.
- **Validate at startup, crash on invalid.** Parse and check every required value before serving.
  Missing or malformed config → log a clear message and exit non-zero. A service that boots with bad
  config and fails later is harder to diagnose than one that refuses to start.
- **No secrets in code or version control.** No hardcoded passwords/keys/tokens; no real secrets in
  a committed `.env`. Load them from the environment or a secret manager. Commit a `.env.example`
  documenting the *keys* with dummy values; gitignore the real `.env`.
- **Fail closed on secrets.** If a secret is absent, refuse to start — never fall back to an empty
  password, a default key, or disabled auth. Only non-secret, safe values may have defaults.
- **Keep secrets out of logs and errors** (see `error-handling-and-logging`). Don't log the config
  struct wholesale; redact secret fields.
- **Parse into real types.** Ints, durations, bools, URLs — validated at load, not re-parsed at each
  use site.
- **Per-environment via values, not code branches.** Inject the right value per environment; avoid
  `if env == "prod"` logic sprinkled through the code.

## Checklist

- [ ] All config read from env into one typed struct at startup
- [ ] Required config validated at boot; process exits non-zero if invalid
- [ ] No hardcoded secrets; real `.env` gitignored, `.env.example` committed
- [ ] Secrets have no default value — absent secret means refuse to start
- [ ] Secret fields never logged or included in error messages
- [ ] Values parsed into real types; env-specific values injected, not branched

## Example

**Bad** — reads env at the use site, hardcoded fallback creds, never validated:
```go
func connect() *DB {
    dsn := os.Getenv("DATABASE_URL")
    if dsn == "" {
        dsn = "postgres://admin:admin@localhost/app" // hardcoded creds; silent insecure fallback
    }
    return open(dsn) // failure surfaces at first query, not at boot
}
```

**Good** — typed config parsed and validated once, fail fast, no default for the secret:
```go
type Config struct {
    DatabaseURL string
    Port        int
    ReadTimeout time.Duration
}

func Load() (Config, error) {
    c := Config{
        Port:        envInt("PORT", 8080),                  // safe, non-secret default
        ReadTimeout: envDuration("READ_TIMEOUT", 5*time.Second),
        DatabaseURL: os.Getenv("DATABASE_URL"),             // secret: no default
    }
    if c.DatabaseURL == "" {
        return Config{}, errors.New("DATABASE_URL is required")
    }
    return c, nil
}

func main() {
    cfg, err := Load()
    if err != nil {
        log.Fatalf("config: %v", err) // exit non-zero before serving a single request
    }
    // cfg passed explicitly from here; never re-read os.Getenv elsewhere
}
```
