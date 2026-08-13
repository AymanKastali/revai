---
name: golang
description: Applies the modern Go style standard — write Go the way the Go team, the standard library and the toolchain say to, using the current release's idioms rather than the ones a 2018 blog post taught. Use when writing, reviewing or refactoring Go code, choosing a Go package layout, wiring errors or context, starting a goroutine, defining an interface or generic, reaching for a dependency the standard library already covers, or writing a Go test or benchmark.
---

# Modern Go style

Go has one formatting answer, one error model, one cancellation model, and a standard library that
absorbs more of what used to need a dependency with every release. Idiomatic Go is therefore not a
matter of taste — it is a matter of knowing which answer is current. This standard is what the Go team
publishes: `gofmt`, `go vet`, the Go Code Review Comments, Google's Go Style Guide, and the release
notes that retired the idioms most Go code still carries.

Scope: this standard governs **how Go itself is written**. What to build a thing out of belongs to
`best-practices`; how the code reads belongs to `clean-code`; how the domain is modelled belongs to
`domain-driven-design`. Where those mandate a property, the rules here name Go's form of it —
`best-practices` requires a timeout, this standard says it is a `context` passed as the first argument.

## Contents

- **Go rules** — 125 rules in twelve groups: the toolchain, names and documentation, types and
  values, errors, context, concurrency, interfaces and generics, the standard library, HTTP, logging,
  and tests. Rules 1–2 gate the standard on the change containing Go and each group on the concern in
  its heading. Parenthesised versions name the release that made the modern form available.
- **Legacy Go and its modern replacement** — 30 idioms that were correct once, each with the current
  answer and the release that introduced it. Read this before copying a pattern from an older
  codebase.
- **Depth** — worked bad/good pairs for the rules that get misread without one.
- **Anti-pattern scan list** — 85 rows, coded by group (`G` toolchain, `N` names, `V` types and
  values, `E` errors, `C` context, `X` concurrency, `I` interfaces and generics, `L` standard library,
  `H` HTTP, `O` logging, `T` tests), to work down while reviewing.

<!-- HARD-RULES:START -->
## Go rules

These are not aspirations. Go code that violates one is not finished.

Rule 1 gates the standard: it governs Go source only. Rule 2 gates each group on the concern named in
its heading. A version in parentheses is the Go release that made that form available — if the module
targets an older release, the rule is advisory until it is raised.

### Rules 1-2 — what applies

1. This standard governs `.go` source. On a change with no Go in it, say so in one line and skip the rest.
2. Each group below names its concern in its heading; only groups whose concern the change touches are in play. Toolchain, names and documentation, errors, and tests always apply to Go code.

### The toolchain is the first reviewer — always applies

3. Every file is `gofmt`-clean. Never hand-format, never fight it, never reformat to taste — a diff that only moves whitespace is noise.
4. Imports are `goimports`-grouped: standard library first, then everything else, separated by one blank line. Never rename an import except to break a genuine collision.
5. `go vet ./...` is clean before the change is finished. Its findings are bugs, not style opinions.
6. `golangci-lint run` is clean with at least the default set — `errcheck`, `govet`, `ineffassign`, `staticcheck`, `unused` — configured by a `.golangci.yml` committed at the module root.
7. `go test -race ./...` passes. The race detector is the arbiter of data races, not your reasoning about them.
8. `go mod tidy` has been run; `go.mod` and `go.sum` are committed and consistent.
9. The `go` directive names a supported release — the current one or the one before it. Never hand-edit the `toolchain` line.
10. Executable dependencies are `tool` directives in `go.mod` (1.24), never a `tools.go` file of blank imports.
11. A suppression names its linter and its reason on the same line — `//nolint:errcheck // Close on a read-only file cannot fail meaningfully`. A bare `//nolint` is a hidden defect.
12. Generated files keep their `// Code generated … DO NOT EDIT.` line and are never edited by hand; change the generator.

### Names, packages and documentation — always applies

13. Package names are lowercase, single-word, no underscores, no plural: `token`, not `tokens`, `token_util` or `tokenUtils`.
14. Never name a package `util`, `utils`, `common`, `helpers`, `shared`, `base`, `misc`, `lib` or `types`. A package with no subject has no reason to exist.
15. The name reads with its package and never stutters: `http.Server`, not `http.HTTPServer`; `token.Parse`, not `token.ParseToken`.
16. Initialisms hold one case throughout: `URL`, `ID`, `HTTP`, `API`, `userID`, `xmlAPI`. Never `Url`, `Id`, `HttpServer`, `userId`.
17. `MixedCaps` exported, `mixedCaps` unexported — including constants. Never `SCREAMING_SNAKE`, never underscores.
18. Name length tracks scope: `i`, `r`, `w`, `b` in a few lines; descriptive names at package scope and for anything long-lived.
19. Receiver names are one or two letters derived from the type and identical on every method of that type. Never `this`, `self` or `me`.
20. No `Get` prefix on an accessor: `u.Name()`, not `u.GetName()`. Use `Fetch`, `Load` or `Compute` when the call does real work, so the cost is visible.
21. Names omit their own type: `users`, not `userSlice`; `count`, not `numUsers`; `limit`, not `limitInt`.
22. Sentinel errors are `ErrThing`/`errThing`; error types are `ThingError`. Interfaces are named for behaviour, `-er` where it reads naturally, and never `IThing`.
23. Code shared inside the module but not part of its API lives under `internal/`. Commands live in `cmd/<name>/`.
24. Follow the official module layout: flat at the root until a package genuinely needs nesting. Do not import the unofficial `pkg/`-and-`api/` scaffold; empty directories are not architecture.
25. Exactly one file per package carries the package comment, immediately above `package`, starting `Package <name> …`.
26. Every exported identifier has a doc comment: a full sentence starting with the identifier's name. Boolean functions read `reports whether`.
27. Document a zero value that means something, and document concurrency safety whenever it is not obvious — read-only is assumed safe, mutating is assumed unsafe.
28. A retired API keeps a paragraph opening `Deprecated:` that names its replacement, and stays until callers have moved.

### Types, values and construction — when the change declares a type, a value or a constructor

29. Make the zero value useful. A type that must be constructed to be valid needs a constructor and a documented reason.
30. `var s []T` for an empty slice, never `[]T{}`. Never let an API distinguish a nil slice or map from an empty one.
31. Accept interfaces, return concrete types. A constructor returning an interface hides what the caller actually has.
32. Never take a pointer to an interface. Never take a pointer only to avoid copying bytes — pass the value.
33. Pointer receiver when the method mutates, when the struct holds a lock or other non-copyable field, or when the struct is genuinely large. Never mix value and pointer receivers on one type.
34. Never copy a value containing a `sync.Mutex`, `sync.WaitGroup`, `atomic.*` or `strings.Builder`. `go vet`'s `copylocks` catches it; heed it.
35. Struct literals name their fields. Positional literals are for two-field types whose order is part of the language, and nowhere else.
36. Enumerations are a named type over `iota` with a `String` method, starting at 1 whenever the zero value must mean "unset" rather than a real case.
37. A primitive with domain meaning gets a named type — `type UserID string` — so the compiler stops you passing an `OrderID` to it.
38. Durations are `time.Duration` and instants are `time.Time` in every Go signature. Never an `int` of seconds or milliseconds, never a string timestamp between Go functions.
39. Every field of a marshalled struct carries an explicit tag; the wire name is a contract and must not follow a rename. Use `omitzero` for zero values (1.24) and `omitempty` only for genuinely absent collections.
40. Type assertions use the comma-ok form. A bare `x.(T)` is an unhandled panic.
41. Embedding is composition, not inheritance. Never embed a type in an exported struct to reuse its methods — its whole API becomes yours forever. Delegate explicitly.
42. Never shadow a predeclared identifier or an imported package: `len`, `cap`, `new`, `min`, `max`, `clear`, `error`, `string`, `any`, `url`, `path`.
43. Copy a slice or map at an API boundary before storing or returning it. Handing out your internal map lets the caller mutate your state.
44. Mutable package-level state is banned. Dependencies are fields on a struct, wired from `main`. Package-level `var` is for sentinel errors, lookup tables and genuinely immutable values.
45. `init()` does no IO, starts no goroutine, and reads no flag or environment variable. Prefer explicit construction called from `main`.
46. Prefer `:=` when initialising with a real value and `var` when the zero value is the point. Preallocate with `make(T, 0, n)` only when `n` is known.

### Errors — always applies

47. Errors are values, returned last, of type `error`. Never signal failure in band with `-1`, `""`, `nil` or a bare `bool`.
48. Every returned error is handled at the point it appears: returned, wrapped and returned, or explicitly discarded as `_ = f()` with a comment saying why that is safe.
49. Wrap with `%w` when a caller may reasonably inspect the cause; use `%v` when deliberately closing the abstraction at a boundary. Document which you do.
50. Put `%w` at the end so the message reads as a chain — `fmt.Errorf("load config: %w", err)` — except for a sentinel category, which leads: `fmt.Errorf("%w: missing header", ErrInvalid)`.
51. Error strings are lowercase, unpunctuated, and add information the wrapped error lacks. Never `"failed to "`, never `"error: "` — the chain already says it failed.
52. Compare with `errors.Is` and extract with `errors.As` (or `errors.AsType[T]`, 1.26). Never `==` against a wrappable error and never match on message text.
53. Give callers something to branch on: a documented sentinel or a typed error with fields. A message is not an API.
54. `errors.Join` (1.20) for independent failures — validating every field, closing every resource — instead of returning only the first.
55. Panic only on a programmer error that a test will catch. Library code returns errors. Never `recover` merely to stay alive; recovering into unknown state is worse than crashing.
56. `os.Exit` and `log.Fatal` appear only in `main`. Every other function returns an error.
57. `main` is a thin wrapper over `run(ctx) error` — `os.Exit` skips every deferred call, so the exit must happen where nothing is deferred.
58. `defer` the cleanup immediately after acquiring the thing, so no later return path can skip it.
59. On a writer, the deferred `Close` error is checked — that is where a buffered write actually fails. Ignoring it silently loses data.
60. A `Must…` function panics on failure and is called only from package initialisation or tests.

### Context — when the change does IO, blocks, or serves a request

61. `ctx context.Context` is the first parameter of any function that does IO, blocks, or serves a request. Never a struct field, never a later parameter, never a custom context type.
62. Only an entry point creates a root context. Below `main`, a test, or a request handler, propagate the caller's: `r.Context()` in an HTTP handler, `t.Context()` in a test (1.24).
63. Every `WithCancel`, `WithTimeout`, `WithDeadline` and `WithCancelCause` is followed by `defer cancel()`. A missing `cancel` leaks the timer and the parent's child list.
64. Any loop or `select` that can block honours `ctx.Done()`, and returns `ctx.Err()` when it fires.
65. `context.WithValue` carries request-scoped metadata only — trace and request IDs, authenticated identity — keyed by an unexported type. Never pass dependencies, configuration or optional arguments through it.
66. A context belongs to one call. Never store one for later, and never hand a cancelled context to new work.
67. Cancellation is not failure. Return `context.Canceled` unwrapped where callers distinguish it, and do not log it as an error.

### Concurrency — when the change starts a goroutine or shares state

68. Never start a goroutine without knowing exactly how it ends. Every one is waited on, or bound to a context that will cancel it.
69. `wg.Go(func(){…})` (1.25) or `errgroup.Group` instead of hand-rolled `Add`/`Done`. `wg.Add` never goes inside the goroutine it counts.
70. Bounded fan-out uses `errgroup.Group` with `SetLimit`. One goroutine per item of an unbounded input is a defect.
71. Prefer synchronous functions. A function that returns a result is composable; one that takes a callback or returns a channel forces its concurrency on every caller.
72. A mutex is a zero-value `sync.Mutex` declared immediately above the fields it guards, with a comment naming them. Never a `*sync.Mutex` field and never an embedded one — embedding publishes `Lock` as API.
73. Lock and unlock in the same function, with `defer mu.Unlock()` on the line after `Lock()`, unless a measured hot path justifies otherwise and says so.
74. Channels are unbuffered, or buffered with 1. Any other size is a written-down capacity decision, not a guess.
75. The sender closes the channel, never the receiver, and never a channel with more than one sender. Closing is a broadcast, not a cleanup.
76. Declare channel direction in every parameter — `<-chan T`, `chan<- T` — so ownership is in the signature.
77. `sync/atomic`'s types (`atomic.Int64`, `atomic.Bool`, `atomic.Pointer[T]`, 1.19), never the loose functions over a bare variable.
78. `sync.Once`, `sync.OnceFunc` or `sync.OnceValue` (1.21) for one-time initialisation, never a `bool` guard.
79. `time.Sleep` is never synchronisation. Wait on a channel, a `sync.WaitGroup`, or a context.
80. `select` with a `time.After` inside a loop leaks a timer per iteration. Use a `time.Timer` you reset, or a context deadline.
81. Nothing captured by a goroutine is mutated by another without a mutex, a channel or an atomic — including the loop variable of a range whose body spawns work.

### Interfaces and generics — when the change declares either

82. The consumer declares the interface, in the consumer's package, as small as the consumer's need. An interface next to its only implementation is inverted.
83. Do not declare an interface with one implementation and no second caller. Add it when the second arrives.
84. Interfaces are behaviour, not data. A method set that is a struct's fields with `Get` in front is not an abstraction.
85. Reach for generics only when the identical code is genuinely needed for several types. Two short concrete functions beat one clever generic one.
86. Never build a DSL out of type parameters. If the signature needs a diagram, write the concrete code.
87. Constrain with the standard library — `any`, `comparable`, `cmp.Ordered` (1.21). A constraint only one type satisfies means the parameter should be that type.
88. `any`, never `interface{}` (1.18).

### The standard library first — when the change reaches for an API or a dependency

89. Search the standard library before adding a dependency: `slices`, `maps`, `cmp`, `errors`, `strings`, `slog`, `iter`, `net/http`, `encoding/json`, `sync`, `context`. A dependency for what `slices` does is a liability with a version number.
90. `math/rand/v2` (1.22), never `math/rand`. Anything security-relevant — tokens, keys, salts, session IDs — uses `crypto/rand`, with `crypto/rand.Text` (1.24) for random strings.
91. A function producing a sequence returns `iter.Seq[V]` or `iter.Seq2[K, V]` (1.23), named `All`, `Keys`, `Values` or `Backward`, and returns as soon as `yield` returns false. Never invent a callback iteration protocol.
92. `strconv` for number-to-string conversion, not `fmt.Sprintf`. `strings.Builder` for accumulation, not `+=` in a loop.
93. `for i := range n` for counted loops (1.22); `min`, `max`, `clear` (1.21) and `cmp.Or` (1.22) instead of hand-written helpers. Never write a Go 1.21 loop-variable capture workaround — 1.22 made the variable per-iteration.
94. `net.JoinHostPort`, never `fmt.Sprintf("%s:%d", host, port)` — `go vet`'s `hostport` analyser (1.25) flags it because it breaks on IPv6.
95. Paths are built with `path/filepath`, never string concatenation. Any path derived from input stays inside a boundary enforced by `os.Root` (1.24), not by inspecting the string.
96. `context`-aware standard library calls where they exist: `db.QueryContext`, `http.NewRequestWithContext`, `exec.CommandContext`. A call without the `Context` variant cannot be cancelled.
97. Every dependency is pinned in `go.mod` and upgraded deliberately. No `replace` directive reaches the default branch.

### HTTP clients and servers — when the change speaks HTTP

98. Servers are a configured `&http.Server{}` with `ReadHeaderTimeout`, `ReadTimeout`, `WriteTimeout` and `IdleTimeout` set. `http.ListenAndServe` with the default server has no timeouts and will be held open by one slow client.
99. Clients are a configured `*http.Client` with a `Timeout`, owned and reused. Never `http.Get`, `http.Post` or `http.DefaultClient` outside a throwaway script — `DefaultClient` has no timeout and is shared process-wide.
100. Every response body is closed, on every path including error paths, and drained before closing when the connection should be reused.
101. `http.ServeMux` method-and-wildcard patterns — `"POST /orders/{id}"` (1.22) — before adding a router dependency.
102. A handler takes its context from `r.Context()` and passes it down. `context.Background()` in a handler makes the request uncancellable.
103. Decode with `json.Decoder` over the body rather than reading it all first, and call `DisallowUnknownFields` where the input is a contract you enforce.
104. Decode into a struct, never `map[string]any`, whenever the shape is known. A map defers every type error to runtime.
105. Shut down on signal: `signal.NotifyContext`, then `Server.Shutdown(ctx)` with a bounded grace period, then wait for in-flight work.
106. `http.Error` and an explicit status code — never a bare `panic` in a handler, and never rely on `net/http`'s panic recovery, which the Go team calls a mistake.

### Logging — when the change emits a log line

107. `log/slog` (1.21) for application logs. Never `fmt.Println`, never `log.Printf`, never a third-party structured logger in new code without a written reason.
108. The logger is injected — a field, or taken from context — not a package-level global. `slog.SetDefault` is a `main`-only concession for libraries you do not control.
109. Use the `…Context` methods (`InfoContext`, `ErrorContext`) so a handler can attach trace and request IDs from the context.
110. A type holding a secret implements `slog.LogValuer` and returns a redacted value, so it cannot be logged by accident from anywhere.
111. Log it or return it, never both. Wrapping and returning is the caller's information; logging as well duplicates every failure up the stack.

### Tests and benchmarks — always applies

112. Tests are table-driven with named cases and `t.Run` subtests; case structs use field names so a reordering cannot silently rewire them.
113. Variables are `got` and `want`, and a failure reads `Func(args) = got, want want` — inputs, actual, expected, in that order.
114. Compare composites with `cmp.Diff`; `reflect.DeepEqual` only where `cmp` genuinely cannot work. Never assert on a formatted string when you mean the value.
115. Never write an assertion helper package. Keep assertions in the test. Helpers do setup and cleanup, call `t.Helper()`, and use `t.Fatal` only for setup that failed.
116. `t.Fatal` only from the test's own goroutine; anywhere else it is `t.Error` and `return`.
117. `t.Cleanup`, `t.TempDir`, `t.Setenv`, `t.Chdir` and `t.Context` instead of hand-rolled teardown, temp directories, environment juggling or `context.Background()`.
118. `t.Parallel()` wherever the test has no shared mutable state — and then no `t.Setenv`, which is incompatible with it.
119. Concurrent and time-dependent tests use `testing/synctest` (1.25): `synctest.Test` runs the body in a bubble with a fake clock, and `synctest.Wait` blocks until every goroutine in it is durably blocked. A `time.Sleep` used to wait for a goroutine is a flake with a timer on it.
120. HTTP is tested with `httptest.Server` and `httptest.NewRecorder`. No unit test touches the real network, the real clock or the real filesystem outside `t.TempDir`.
121. Benchmarks loop with `for b.Loop()` (1.24), which keeps setup out of the measurement and stops the compiler eliminating the body. Never `for i := 0; i < b.N; i++` in new code.
122. Every parser, decoder or anything taking untrusted bytes gets a `Fuzz` target, with its seed corpus committed.
123. Exported API whose usage is not obvious from its signature carries an `Example` function with an `// Output:` comment, so the documentation is compiled and verified.
124. Test the public surface from an external `package foo_test` unless the test genuinely needs an unexported identifier.
125. A test that fails under `-race`, or under `-shuffle=on`, is a defect in the test or the code — never a reason to drop the flag.
<!-- HARD-RULES:END -->

## Legacy Go and its modern replacement

Every left-hand column was correct Go once. Each is now a signal that the code — or the habit that
wrote it — predates the release in the third column. Check this table before copying a pattern out of
an older codebase.

| Concern | Legacy form | Modern Go |
| --- | --- | --- |
| Empty interface | `interface{}` | `any` (1.18) |
| Counted loop | `for i := 0; i < n; i++` | `for i := range n` (1.22) |
| Loop variable capture | `x := x` before `go func()` | nothing — the variable is per-iteration (1.22) |
| Randomness | `math/rand`, `rand.Seed` | `math/rand/v2` (1.22); `crypto/rand` when it matters |
| Random string | hand-rolled alphabet loop | `crypto/rand.Text` (1.24) |
| Read a file | `ioutil.ReadFile`, `ioutil.ReadAll` | `os.ReadFile`, `io.ReadAll` (1.16) |
| Temp dir in a test | `ioutil.TempDir` + `defer os.RemoveAll` | `t.TempDir()` |
| Sorting | `sort.Slice`, `sort.Ints`, `sort.Strings` | `slices.Sort`, `slices.SortFunc` (1.21) |
| Searching a slice | hand-written index loop | `slices.Contains`, `slices.Index`, `slices.BinarySearch` (1.21) |
| Map keys as a slice | `for k := range m` into a slice | `slices.Sorted(maps.Keys(m))` (1.23) |
| Emptying a map | `for k := range m { delete(m, k) }` | `clear(m)` (1.21) |
| Min / max | a hand-written `minInt` helper | `min`, `max` builtins (1.21) |
| First non-zero value | `if x != "" { … } else { … }` | `cmp.Or(x, fallback)` (1.22) |
| Ordered constraint | `golang.org/x/exp/constraints.Ordered` | `cmp.Ordered` (1.21) |
| Iterating a container | an `Each(func(T) bool)` callback | `iter.Seq[T]` + range-over-func (1.23) |
| Error wrapping | `github.com/pkg/errors` | `fmt.Errorf` with `%w`, `errors.Is`, `errors.As` (1.13) |
| Multiple errors | first error wins, or a custom multierror | `errors.Join` (1.20) |
| Extracting a typed error | `var e *MyErr; errors.As(err, &e)` | `errors.AsType[*MyErr](err)` (1.26) |
| Application logging | `log.Printf`, `fmt.Println` | `log/slog` (1.21) |
| Waiting on goroutines | `wg.Add(1)`; `go func(){ defer wg.Done() }` | `wg.Go(func(){ … })` (1.25) |
| Bounded fan-out | a semaphore channel you built | `errgroup.Group` + `SetLimit` |
| Atomic counter | `atomic.AddInt64(&n, 1)` | `atomic.Int64` (1.19) |
| One-time value | `sync.Once` + a package var | `sync.OnceValue` (1.21) |
| Routing method + path | a router dependency for `POST /x/{id}` | `http.ServeMux` patterns (1.22) |
| Constraining a path | `filepath.Clean` and hope | `os.OpenRoot`, `os.Root` (1.24) |
| Omitting a zero field | `omitempty` on an `int` or `time.Time` | `omitzero` (1.24) |
| Tool dependencies | a `tools.go` of blank imports | `tool` directives in `go.mod` (1.24) |
| Context in a test | `context.Background()` | `t.Context()` (1.24) |
| Testing concurrency | `time.Sleep(50 * time.Millisecond)` | `testing/synctest` (1.25) |
| Benchmark loop | `for i := 0; i < b.N; i++` | `for b.Loop()` (1.24) |

## Depth

### Rules 49-53 — wrap so the caller can act, not so the log looks full

```text
Bad
  if err != nil {
      log.Printf("failed to get user: %v", err)            // logged AND returned (111)
      return fmt.Errorf("failed to get user: %v", err)     // %v discards the cause (49)
  }                                                        // "failed to" says nothing (51)

  if err.Error() == "not found" { … }                      // matching on text (52)

Good
  var ErrNotFound = errors.New("not found")                // a documented sentinel (53)

  func (s *Store) User(ctx context.Context, id UserID) (*User, error) {
      row := s.db.QueryRowContext(ctx, q, id)              // ctx-aware call (96)
      if err := row.Scan(&u); errors.Is(err, sql.ErrNoRows) {
          return nil, fmt.Errorf("user %s: %w", id, ErrNotFound)
      } else if err != nil {
          return nil, fmt.Errorf("scan user %s: %w", id, err)
      }
      return &u, nil
  }

  // caller, one level up, decides — and only the top of the stack logs
  if errors.Is(err, store.ErrNotFound) {
      http.Error(w, "no such user", http.StatusNotFound)
      return
  }
```

The wrap adds the subject the inner error could not know (`user 42`), keeps the cause inspectable with
`%w`, and leaves the decision to the layer that has the response to give.

### Rules 61-64, 68-70 — a goroutine with an owner

```text
Bad
  func (w *Worker) Start() {                    // no ctx, no way to stop (61, 68)
      go func() {
          for {
              w.tick()
              time.Sleep(time.Second)           // sleep as control flow (79)
          }
      }()
  }

Good
  // Run processes jobs until ctx is cancelled, then returns ctx.Err().
  func (w *Worker) Run(ctx context.Context) error {
      t := time.NewTicker(time.Second)
      defer t.Stop()
      for {
          select {
          case <-ctx.Done():
              return ctx.Err()                  // cancellation observed (64)
          case <-t.C:
              if err := w.tick(ctx); err != nil {
                  return fmt.Errorf("tick: %w", err)
              }
          }
      }
  }

  // caller owns the lifetime
  g, ctx := errgroup.WithContext(ctx)
  g.SetLimit(8)                                 // bounded fan-out (70)
  for _, w := range workers {
      g.Go(func() error { return w.Run(ctx) })  // per-iteration variable, 1.22 (93)
  }
  if err := g.Wait(); err != nil && !errors.Is(err, context.Canceled) {
      return err                                // cancellation is not failure (67)
  }
```

`Run` is synchronous and returns an error, so the caller chooses the concurrency (71) and nothing can
outlive it.

### Rule 91 — return a sequence, not a callback

```text
Bad
  func (s *Set[E]) Each(f func(E) bool) { … }   // a protocol every caller must learn

Good
  // All returns an iterator over the set's elements, in no particular order.
  func (s *Set[E]) All() iter.Seq[E] {
      return func(yield func(E) bool) {
          for v := range s.m {
              if !yield(v) {
                  return                        // the caller broke; stop and clean up (91)
              }
          }
      }
  }
```

`for v := range s.All()` then supports `break`, `continue`, `return` and `defer` like any loop, and the
sequence composes: `slices.Sorted(s.All())`, `maps.Keys(m)`, a `Filter` adapter that returns another
`iter.Seq`. A callback protocol supports none of that.

### Rules 112-114, 119 — a test that cannot flake

```text
Bad
  func TestNotify(t *testing.T) {
      go svc.Notify(ctx)
      time.Sleep(100 * time.Millisecond)                  // a flake with a timer (79, 119)
      if !reflect.DeepEqual(svc.sent, want) {             // no diff on failure (114)
          t.Errorf("wrong")                               // says nothing (113)
      }
  }

Good
  func TestNotify(t *testing.T) {
      tests := map[string]struct {
          in   Event
          want []Message
      }{
          "single recipient": {in: Event{…}, want: []Message{…}},
          "no recipients":    {in: Event{…}, want: nil},
      }
      for name, tc := range tests {                            // 1.22: tc is per-iteration
          t.Run(name, func(t *testing.T) {
              t.Parallel()                                     // outside the bubble — inside it is forbidden
              synctest.Test(t, func(t *testing.T) {            // fake clock, no real waiting (119)
                  svc, sent := newService(t)                   // helper sets up, t.Cleanup tears down (117)
                  if err := svc.Notify(t.Context(), tc.in); err != nil {
                      t.Fatalf("Notify(%v) = %v, want no error", tc.in, err)
                  }
                  synctest.Wait()                              // the senders it spawned have settled
                  if diff := cmp.Diff(tc.want, sent.all()); diff != "" {
                      t.Errorf("Notify(%v) sent diff (-want +got):\n%s", tc.in, diff)
                  }
              })
          })
      }
  }
```

`Notify` dispatches and returns; `synctest.Wait` blocks until every goroutine it started is durably
blocked, so the assertion runs against a settled system with no sleep and no timeout anywhere.

## Anti-pattern scan list

Work down this list while reviewing Go. Each row cites the rule that settles it.

| Code | Anti-pattern | Rule |
| --- | --- | --- |
| G1 | File is not `gofmt`-clean, or a diff that only moves whitespace | 3 |
| G2 | Imports ungrouped, or renamed without a collision | 4 |
| G3 | `go vet` or the default `golangci-lint` set has findings | 5, 6 |
| G4 | No `.golangci.yml` at the module root, or tests never run under `-race` | 6, 7 |
| G5 | `go.mod` untidy, or the `go` directive on an unsupported release | 8, 9 |
| G6 | A `tools.go` of blank imports instead of `tool` directives | 10 |
| G7 | A bare `//nolint` with no linter and no reason | 11 |
| G8 | A generated file edited by hand | 12 |
| N1 | Package named `util`, `common`, `helpers`, `shared`, `types` or `base`, or plural, underscored or camelCase | 13, 14 |
| N2 | Name stutters with its package (`token.ParseToken`) | 15 |
| N3 | `Url`, `Id`, `HttpServer`, `userId`, or a `SCREAMING_SNAKE` identifier | 16, 17 |
| N4 | One-letter name at package scope, or a paragraph-long name in a 3-line block | 18 |
| N5 | Receiver named `this`, `self`, `me`, or inconsistent across methods | 19 |
| N6 | `GetName()` accessor, or an expensive call named like a field read | 20 |
| N7 | Name carries its type (`userSlice`), or an error or interface misnamed (`IThing`) | 21, 22 |
| N8 | Non-API code outside `internal/`, or the unofficial `pkg/`-and-`api/` scaffold | 23, 24 |
| N9 | Package comment missing, duplicated or not starting `Package x`; an exported identifier, meaningful zero value, concurrency contract or deprecation left undocumented | 25, 26, 27, 28 |
| V1 | Type unusable until a setter is called, with no constructor | 29 |
| V2 | `[]T{}` for an empty slice, or an API distinguishing nil from empty | 30 |
| V3 | Constructor returns an interface, or a pointer taken only to avoid a copy | 31, 32 |
| V4 | Value and pointer receivers mixed on one type | 33 |
| V5 | A struct holding a mutex, `WaitGroup` or `strings.Builder` copied | 34 |
| V6 | Positional struct literal on a type with more than two fields | 35 |
| V7 | Enum of bare constants, no `String` method, or a zero value silently meaning a real case | 36 |
| V8 | Two different IDs both plain `string`, interchangeable by the compiler | 37 |
| V9 | `int` seconds, `int64` millis or a string timestamp in a Go signature | 38 |
| V10 | Marshalled field with no tag, `omitempty` where `omitzero` is meant, or a bare `x.(T)` | 39, 40 |
| V11 | A type embedded in an exported struct to reuse its methods, or a shadowed builtin | 41, 42 |
| V12 | An internal slice or map handed out uncopied, mutable package state, or `init()` doing work | 43, 44, 45 |
| E1 | Failure signalled by `-1`, `""`, `nil` or a bare `bool`, or an error assigned to `_` with no comment | 47, 48 |
| E2 | `%v` where the caller needs the cause, or `%w` not at the end of the message | 49, 50 |
| E3 | Error string capitalised, punctuated, or prefixed `failed to` | 51 |
| E4 | `err == ErrX` on a wrappable error, or matching on `err.Error()` text | 52 |
| E5 | Callers forced to parse a message because no sentinel or typed error exists | 53 |
| E6 | Only the first of several independent failures returned | 54 |
| E7 | A library panicking on bad input, `recover` used to stay alive, or `log.Fatal` outside `main` | 55, 56 |
| E8 | `main` exiting directly so defers never run; cleanup not deferred at acquisition; a writer's deferred `Close` error discarded | 57, 58, 59 |
| C1 | Blocking or IO function with no `ctx`, `ctx` not first, or `ctx` kept as a struct field | 61 |
| C2 | `context.Background()` below an entry point | 62 |
| C3 | A `cancel` from `WithCancel` or `WithTimeout` not deferred | 63 |
| C4 | A blocking loop or `select` that never checks `ctx.Done()` | 64 |
| C5 | `WithValue` carrying a dependency, a config value or an argument | 65 |
| C6 | A context stored for later or reused after cancellation, or `context.Canceled` reported as a failure | 66, 67 |
| X1 | `go` with no owner, no wait and no cancellation | 68 |
| X2 | `wg.Add` inside its own goroutine, or hand-rolled `Add`/`Done` | 69 |
| X3 | One goroutine per item of an unbounded input, or an API offering only a callback or channel where a return value would do | 70, 71 |
| X4 | `*sync.Mutex` field, an embedded mutex, or a lock with no comment naming what it guards | 72 |
| X5 | `Lock` and `Unlock` in different functions, or `Unlock` not deferred | 73 |
| X6 | Channel buffered to an unexplained size, or closed by a receiver or by one of many senders | 74, 75 |
| X7 | Channel parameter with no direction, or `atomic.AddInt64` on a bare variable | 76, 77 |
| X8 | A `bool` guard where `sync.Once` or `OnceValue` belongs, or `time.Sleep` used to wait | 78, 79 |
| X9 | `time.After` inside a loop, or shared state mutated with no mutex, channel or atomic | 80, 81 |
| I1 | Interface declared beside its only implementation | 82 |
| I2 | Interface with one implementation and no second caller, or one that is a struct's fields with `Get` prefixed | 83, 84 |
| I3 | Generic function used by exactly one type, or type parameters building a DSL | 85, 86 |
| I4 | A hand-written constraint the standard library already provides | 87 |
| I5 | `interface{}` instead of `any` | 88 |
| L1 | A dependency doing what `slices`, `maps`, `cmp` or `errors` does | 89 |
| L2 | `math/rand` at all, or `math/rand` for anything security-relevant | 90 |
| L3 | A callback iteration protocol instead of `iter.Seq`, or an iterator ignoring a false `yield` | 91 |
| L4 | `fmt.Sprintf` for a number, `+=` accumulating a string in a loop, a hand-written `minInt`, or a Go 1.21 loop-capture workaround | 92, 93 |
| L5 | `fmt.Sprintf("%s:%d", host, port)` | 94 |
| L6 | A path built by concatenation, or an input path guarded only by `filepath.Clean` | 95 |
| L7 | `db.Query`, `http.NewRequest` or `exec.Command` where a `Context` variant exists, or a `replace` on the default branch | 96, 97 |
| H1 | `http.ListenAndServe`, or a server with any timeout unset | 98 |
| H2 | `http.Get`, `http.Post` or `http.DefaultClient` in production code | 99 |
| H3 | A response body not closed on every path, or not drained before reuse | 100 |
| H4 | A router dependency added for method-and-path routing | 101 |
| H5 | A handler using `context.Background()` instead of `r.Context()` | 102 |
| H6 | Body read fully into memory before decoding, unknown fields accepted silently, or JSON decoded into `map[string]any` when the shape is known | 103, 104 |
| H7 | No graceful shutdown, or a handler that panics and leans on `net/http` recovering it | 105, 106 |
| O1 | `fmt.Println` or `log.Printf` for an application log | 107 |
| O2 | A package-level logger global outside `main`, or `slog.Info` where `slog.InfoContext` would carry the trace ID | 108, 109 |
| O3 | A secret-bearing type with no `LogValuer` redaction | 110 |
| O4 | An error both logged and returned | 111 |
| T1 | Repeated near-identical test functions instead of a table, subtests unnamed, or case structs built positionally | 112 |
| T2 | Failure message missing the input, the got or the want, or `reflect.DeepEqual` where `cmp.Diff` would show the difference | 113, 114 |
| T3 | A home-grown assertion helper package, or a helper with no `t.Helper()` | 115 |
| T4 | `t.Fatal` from a non-test goroutine | 116 |
| T5 | Manual teardown, temp dir, env restore or `context.Background()` in a test | 117 |
| T6 | `t.Setenv` together with `t.Parallel()` | 118 |
| T7 | `time.Sleep` waiting for a goroutine instead of `synctest` | 119 |
| T8 | A unit test touching the real network, clock or filesystem | 120 |
| T9 | `for i := 0; i < b.N; i++`, no fuzz target on an untrusted parser, or no verified `Example` | 121, 122, 123 |
| T10 | Public API tested from inside the package with no need for an unexported identifier, or a test dropping `-race` or `-shuffle` because it fails | 124, 125 |
