# Capacity estimation

## Contents
Why this is worth doing even when scale "feels obvious" · the four numbers · worked example ·
checklist.

Back-of-envelope math, not precision. The point isn't a defensible forecast — it's catching the one
number (a write-heavy path that looked read-heavy, a bandwidth figure nobody sized) that changes the
architecture before the architecture is fixed. Skipping this because a system "feels" small or large
is how that number gets missed; a system that's genuinely trivial still gets the two-line version,
which mostly confirms there's nothing here and moves on.

## The four numbers

- **Read/write ratio.** Read-heavy (Twitter-style, ~100:1) pushes toward caching and read replicas.
  Write-heavy (IoT/logging-style, ~1:10) pushes toward write throughput, batching, and a storage
  engine built for ingest. State the ratio explicitly — "roughly balanced" is a valid answer, but
  state it rather than defaulting to an assumption.
- **Storage.** `(size per record) × (records per day) × (retention period)`. Round generously; the
  goal is "gigabytes, terabytes, or petabytes," not an exact figure. This number decides whether a
  single instance's disk is fine or partitioning/sharding is a live concern (see
  `reference/data-layer-architecture.md`).
- **Bandwidth.** Ingress and egress, separately, in requests/sec × average payload size. A read-heavy
  API with large payloads (video, images) has a very different egress profile than a write-heavy
  API with small JSON bodies — the number changes what the ingress layer and CDN strategy need to be
  (see `reference/high-level-architecture-diagramming.md`).
- **Hot-data / cache footprint.** Apply the 80/20 rule as a starting point: assume roughly 20% of
  daily data accounts for the bulk of reads, and size a cache for that slice. This is the input to
  the caching decision `/revai:decide`'s dimension checklist already asks about — this reference
  supplies the number, not a new caching rule.

## Worked example

A notifications service, 2M daily active users, each triggering ~5 notification events/day, each
event ~500 bytes, retained 90 days:

- Read/write ratio: writes on event ingest, reads on delivery + a user's history view — call it
  roughly 3:1 read-heavy once delivery fan-out is counted.
- Storage: `500 B × 10M events/day × 90 days ≈ 4.5 GB` — trivially small; no partitioning driven by
  storage volume alone.
- Bandwidth: 10M events/day ≈ 116 events/sec average ingress; delivery fan-out (assume 1 push per
  event) is the dominant egress cost, not the ingest side.
- Hot data: the last 24-48 hours of a user's notifications are the read-heavy slice — that's the
  cache candidate, not the full 90-day history.

Four short lines, and the finding that matters (delivery fan-out, not ingest, is the real load) falls
out of doing the math rather than guessing.

## Checklist

- [ ] Read/write ratio is stated as a number or a named shape ("read-heavy", "write-heavy",
      "balanced"), not assumed silently
- [ ] Storage estimate uses the three-factor formula, even when the answer is "trivially small"
- [ ] Ingress and egress bandwidth are estimated separately, not conflated into one number
- [ ] A hot-data/cache-footprint figure is stated, feeding the caching dimension rather than
      re-deciding it here
- [ ] Depth is proportional to the stakes — a low-scale system states this plainly in a couple of
      lines rather than being padded to look thorough
