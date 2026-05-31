# SKILL: Resilience Patterns · v2026.11
> Load when: calling external APIs, building services that must survive failures, or handling network/timeout errors.
> Covers: retry, circuit breaker, timeout, bulkhead, fallback, rate limiting, Flutter offline mode

## DETECT FIRST
```bash
# Existing resilience libs?
cat package.json | grep -E "cockatiel|opossum|p-retry|axios-retry|bottleneck|p-limit"
cat requirements.txt | grep -E "tenacity|circuitbreaker|httpx|aiohttp"
cat pubspec.yaml | grep -E "retry|dio|connectivity_plus"
# Any existing retry logic?
grep -r "retry\|setTimeout\|catch.*retry" src/ lib/ --include="*.ts" --include="*.dart" -l | head -5
```

---

## CORE PRINCIPLE

**Every call to an external system can fail.** Resilience is designing for that reality, not hoping it won't happen.

```
Retry          → transient failures (network blip, 503)
Circuit Breaker → cascading failure prevention (service down)
Timeout        → unbounded waits (slow service hangs your thread)
Bulkhead       → isolation (one slow service can't exhaust all connections)
Fallback       → graceful degradation (serve stale, serve default)
```

---

## RETRY

### Node.js — cockatiel (best-in-class)
```typescript
import { retry, ExponentialBackoff, handleResultType, handleTransientErrors } from 'cockatiel';

const retryPolicy = retry(
  handleTransientErrors(), // 5xx, network errors
  {
    maxAttempts: 3,
    backoff: new ExponentialBackoff({ initialDelay: 100, maxDelay: 5000 }),
  }
);

// Wrap any async operation
const result = await retryPolicy.execute(() => fetch('https://api.example.com/data'));
```

### Retry: what to retry vs not
```typescript
// ✅ RETRY: transient errors
const RETRYABLE = new Set([408, 429, 500, 502, 503, 504]);

// ❌ NEVER RETRY: client errors, non-idempotent without check
const NEVER_RETRY = new Set([400, 401, 403, 404, 422]);
// Exception: 429 with Retry-After header → respect the header
```

### Respect Retry-After header (429)
```typescript
async function callWithRespect(url: string): Promise<Response> {
  const res = await fetch(url);
  if (res.status === 429) {
    const retryAfter = parseInt(res.headers.get('retry-after') ?? '5', 10);
    await sleep(retryAfter * 1000);
    return fetch(url); // one retry
  }
  return res;
}
```

### Python — tenacity
```python
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type
import httpx

@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=0.1, max=10),
    retry=retry_if_exception_type((httpx.TransportError, httpx.HTTPStatusError)),
    reraise=True,
)
async def call_api(url: str) -> dict:
    async with httpx.AsyncClient() as client:
        response = await client.get(url, timeout=10.0)
        response.raise_for_status()
        return response.json()
```

---

## CIRCUIT BREAKER

**State machine:** CLOSED (normal) → OPEN (failing, reject fast) → HALF-OPEN (probe) → CLOSED

### Node.js — cockatiel
```typescript
import { circuitBreaker, ConsecutiveBreaker, SamplingBreaker, handleAll } from 'cockatiel';

const breaker = circuitBreaker(handleAll(), {
  halfOpenAfter: 10_000, // 10s before probing
  breaker: new SamplingBreaker({
    threshold: 0.5,        // open when 50%+ requests fail
    duration: 30_000,      // sampling window: 30s
    minimumRps: 5,         // min requests before it can open
  }),
});

// Combine with retry — retry INSIDE circuit breaker
const policy = wrap(retryPolicy, breaker);

try {
  const data = await policy.execute(() => externalApiCall());
} catch (err) {
  if (err instanceof BrokenCircuitError) {
    // Circuit open — return fallback immediately
    return getFallback();
  }
  throw err;
}

// Observe state changes
breaker.onStateChange(state => {
  logger.warn({ state }, 'circuit-breaker state change');
  metrics.gauge('circuit_breaker_state', state === 'open' ? 1 : 0, { service: 'payment' });
});
```

### Python — circuitbreaker
```python
from circuitbreaker import circuit, CircuitBreakerError

@circuit(failure_threshold=5, recovery_timeout=30, expected_exception=Exception)
async def call_payment_service(order_id: str) -> dict:
    async with httpx.AsyncClient() as client:
        res = await client.post('/charge', json={'order_id': order_id}, timeout=5.0)
        res.raise_for_status()
        return res.json()

# In caller
try:
    result = await call_payment_service(order_id)
except CircuitBreakerError:
    log.warning("payment.circuit_open", order_id=order_id)
    return {'status': 'queued', 'message': 'Payment processing delayed'}
```

---

## TIMEOUTS

**Every external call needs a timeout. No exceptions.**

```typescript
// Node.js — AbortController (native)
async function fetchWithTimeout(url: string, ms = 5000): Promise<Response> {
  const controller = new AbortController();
  const id = setTimeout(() => controller.abort(), ms);
  try {
    return await fetch(url, { signal: controller.signal });
  } finally {
    clearTimeout(id);
  }
}

// Axios
const client = axios.create({ timeout: 5000 });

// Differentiating timeout vs other errors
import { isAxiosError } from 'axios';
try {
  await client.get(url);
} catch (err) {
  if (isAxiosError(err) && err.code === 'ECONNABORTED') {
    log.warn({ url }, 'request.timeout');
    // timeout-specific handling
  }
}
```

```python
# httpx — always set timeouts explicitly
async with httpx.AsyncClient(
    timeout=httpx.Timeout(connect=2.0, read=10.0, write=5.0, pool=1.0)
) as client:
    try:
        res = await client.get(url)
    except httpx.TimeoutException as e:
        log.warning("request.timeout", url=url, error=str(e))
        raise
```

---

## BULKHEAD — Concurrency Limits

Prevent one slow dependency from consuming all worker threads/connections.

```typescript
// Node.js — p-limit
import pLimit from 'p-limit';

const paymentLimit = pLimit(5);   // max 5 concurrent payment calls
const storageLimit = pLimit(20);  // max 20 concurrent S3 calls

// Use separate limits per dependency
const results = await Promise.all(
  orders.map(order => paymentLimit(() => chargeOrder(order)))
);
```

```typescript
// Database connection pool as bulkhead (Prisma/pg)
const db = new Pool({
  max: 10,             // max connections this service holds
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 2_000, // fail fast if pool exhausted
});
```

---

## FALLBACK PATTERNS

```typescript
// Stale cache fallback
async function getUserProfile(userId: string): Promise<UserProfile> {
  const cacheKey = `profile:${userId}`;
  try {
    const fresh = await profileService.get(userId);
    await cache.set(cacheKey, fresh, { ttl: 300 }); // update cache
    return fresh;
  } catch (err) {
    log.warn({ userId, err }, 'profile.service.degraded — serving stale cache');
    const stale = await cache.get(cacheKey);
    if (stale) return stale;
    return getDefaultProfile(userId); // last resort default
  }
}

// Feature flag / graceful degradation
async function getRecommendations(userId: string): Promise<Product[]> {
  try {
    return await recommendationEngine.get(userId);
  } catch {
    // Recommendation engine down → serve bestsellers (simpler, more reliable)
    return await getTopSellers({ limit: 10 });
  }
}
```

---

## FLUTTER — Offline & Connectivity

```dart
// connectivity_plus + retry
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

class ResilientApiClient {
  final Dio _dio;
  
  ResilientApiClient() : _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 5),
  )) {
    _dio.interceptors.add(RetryInterceptor(
      dio: _dio,
      retries: 3,
      retryDelays: const [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)],
      retryEvaluator: (error, attempt) =>
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        (error.response?.statusCode ?? 0) >= 500,
    ));
  }

  Future<T> call<T>(Future<T> Function() fn) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      throw OfflineException('No network connection');
    }
    return fn();
  }
}
```

```dart
// Offline queue — persist ops, replay when online
class OfflineQueue {
  static Future<void> enqueue(PendingOperation op) async {
    final box = Hive.box<PendingOperation>('offline_queue');
    await box.add(op);
  }

  static Future<void> flush() async {
    final box = Hive.box<PendingOperation>('offline_queue');
    for (final op in box.values.toList()) {
      try {
        await op.execute();
        await op.delete();
      } catch (e) {
        if (!isRetryable(e)) await op.delete(); // don't retry 4xx
      }
    }
  }
}
```

---

## IDEMPOTENCY — Safe Retry for Mutations

```typescript
// Generate idempotency key on client, send with request
// Server: if seen before → return cached result, don't re-process
const idempotencyKey = `charge_${orderId}_${userId}`;

const response = await fetch('/api/payments', {
  method: 'POST',
  headers: {
    'Idempotency-Key': idempotencyKey,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({ amount, currency }),
});
```

```typescript
// Server-side: store results keyed by idempotency-key (Redis, 24h TTL)
async function handleCharge(req: Request) {
  const key = req.headers.get('idempotency-key');
  if (key) {
    const cached = await redis.get(`idempotency:${key}`);
    if (cached) return Response.json(JSON.parse(cached)); // replay
  }
  
  const result = await chargeCard(req.body);
  
  if (key) {
    await redis.setex(`idempotency:${key}`, 86400, JSON.stringify(result));
  }
  return Response.json(result);
}
```

---

## CHECKLIST — For every external call

```
[ ] Timeout set? (connect + read separately)
[ ] Retry only on idempotent or idempotency-keyed operations?
[ ] Retry backoff is exponential with jitter?
[ ] Circuit breaker wraps high-volume dependency?
[ ] Bulkhead limits max concurrency to dependency?
[ ] Fallback returns something useful (stale/default)?
[ ] Failure logged with enough context to debug?
[ ] Metrics emitted: success/failure/latency per dependency?
[ ] Flutter: offline case handled gracefully (queue or error UI)?
```
