# Caching

A cache is a performance optimization bolted onto a data source, and every rule here exists because
caches fail in ways plain reads don't: a stampede after expiry, a stale authorization decision, a
schema change that returns garbage from an old key. These rules keep a cache invisible to the domain
and safe to lose.

## Rules

- **Cache lives in the infra/adapter layer, behind the same port as the uncached path.** Domain and
  app code call a repository/port method; whether that call hit a cache or the source of truth is an
  adapter detail. Never let domain code branch on "is this cached."
- **Default to cache-aside** unless there's a stated reason to pick something else. Read: check
  cache, on miss load from source and populate the cache. Write: either write-through (write cache
  and source together) or invalidate the key so the next read repopulates it. Write-behind (write
  cache, flush to source later) trades durability for latency — only pick it deliberately, knowing
  what's lost if the cache dies before the flush.
- **Every entry has an explicit TTL or an explicit invalidation trigger — never neither.** A cache
  entry with no TTL and nothing that invalidates it on change is a permanent staleness bug waiting
  to be found in production.
- **Guard hot keys against a stampede.** When a popular key expires, don't let every concurrent
  caller miss at once and hammer the source simultaneously. Use a lock/singleflight so only one
  caller repopulates while the rest wait, or jittered early expiration so refreshes spread out
  before the hard expiry.
- **Namespace and version cache keys.** Include a schema/version segment in the key (e.g.
  `user:v3:{id}`) so a shape change to the cached value can't silently return old, incompatible data
  under a key some code still expects the new shape from — bump the version instead of trying to
  migrate cached bytes in place.
- **Never cache an authorization decision without a short TTL and change-triggered invalidation.** A
  cached "allowed" that outlives a permission revocation is a real security gap, not just staleness.
- **A cache outage fails open to the source of truth.** If the cache is unreachable, read through to
  the DB/API rather than hard-failing the request — a cache is an optimization, and its absence
  should degrade latency, not availability.

## Checklist

- [ ] Domain/app code calls a port method; it never knows or branches on whether a read was cached
- [ ] Cache-aside is the default; write-through/write-behind is a stated, deliberate choice
- [ ] Every cache entry has either an explicit TTL or an explicit invalidation trigger
- [ ] Hot-key expiry is guarded against stampede (lock/singleflight or jittered early expiration)
- [ ] Cache keys are namespaced and include a schema/version segment
- [ ] Cached authorization decisions have a short TTL and invalidate on permission change
- [ ] A cache being down degrades to the source of truth, not a hard failure

## Examples

### Go

**Bad** — no TTL, no key versioning, and a cache miss on a hot key lets every concurrent caller hit
the DB at once:

```go
func (r *UserRepo) GetUser(ctx context.Context, id string) (*User, error) {
    if v, ok := r.cache.Get("user:" + id); ok { // no version segment in the key
        return v.(*User), nil
    }
    u, err := r.db.QueryUser(ctx, id) // every concurrent miss hits the DB — no stampede guard
    if err != nil {
        return nil, err
    }
    r.cache.Set("user:"+id, u) // no TTL: stays cached forever, never invalidated on update
    return u, nil
}
```

**Good** — versioned/namespaced key, explicit TTL, singleflight collapses concurrent misses into one
DB call, and the domain layer sees only the `UserRepo` port either way:

```go
const userCacheVersion = "v2" // bump on any shape change to User

type UserRepo struct {
    cache      Cache
    db         *sql.DB
    single     singleflight.Group // collapses concurrent misses for the same key
}

func (r *UserRepo) GetUser(ctx context.Context, id string) (*User, error) {
    key := fmt.Sprintf("user:%s:%s", userCacheVersion, id)
    if v, ok := r.cache.Get(key); ok {
        return v.(*User), nil
    }
    // only one goroutine per key actually queries; the rest wait on its result
    v, err, _ := r.single.Do(key, func() (any, error) {
        u, err := r.db.QueryUser(ctx, id)
        if err != nil {
            return nil, err
        }
        r.cache.SetWithTTL(key, u, 5*time.Minute) // explicit TTL — never cached forever
        return u, nil
    })
    if err != nil {
        return nil, err
    }
    return v.(*User), nil
}

func (r *UserRepo) UpdateUser(ctx context.Context, u *User) error {
    if err := r.db.SaveUser(ctx, u); err != nil {
        return err
    }
    key := fmt.Sprintf("user:%s:%s", userCacheVersion, u.ID)
    return r.cache.Delete(key) // invalidate on write instead of leaving stale data cached
}
```

### Python

**Bad** — caches an authorization decision with no TTL, and falls over hard when the cache is down
instead of reading through to the source:

```python
def can_access(cache, db, user_id: str, resource_id: str) -> bool:
    key = f"perm:{user_id}:{resource_id}"  # no version segment
    cached = cache.get(key)  # raises if the cache is down — no fail-open path
    if cached is not None:
        return cached
    allowed = db.check_permission(user_id, resource_id)
    cache.set(key, allowed)  # no TTL: a later revocation never invalidates this
    return allowed
```

**Good** — versioned key, short TTL on the authorization decision, and a cache outage degrades to
reading the source of truth instead of failing the request:

```python
PERM_CACHE_VERSION = "v1"

def can_access(cache, db, user_id: str, resource_id: str) -> bool:
    key = f"perm:{PERM_CACHE_VERSION}:{user_id}:{resource_id}"
    try:
        cached = cache.get(key)
    except CacheUnavailable:
        cached = None  # fail open: treat as a miss rather than failing the request

    if cached is not None:
        return cached

    allowed = db.check_permission(user_id, resource_id)
    try:
        # short TTL: an authorization decision must not outlive a permission change for long
        cache.set(key, allowed, ttl=30)
    except CacheUnavailable:
        pass  # caching is best-effort; the source of truth already answered the request
    return allowed

def revoke_permission(cache, db, user_id: str, resource_id: str) -> None:
    db.revoke(user_id, resource_id)
    key = f"perm:{PERM_CACHE_VERSION}:{user_id}:{resource_id}"
    cache.delete(key)  # invalidate immediately rather than waiting out the TTL
```
