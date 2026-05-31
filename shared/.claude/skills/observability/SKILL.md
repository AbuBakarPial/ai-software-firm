# SKILL: Observability · v2026.11
> Load when: adding logging, tracing, metrics, alerts, or debugging production issues.
> Covers: structured logs, OpenTelemetry, Prometheus/Grafana, distributed tracing, alerting, Flutter crash reporting

## DETECT FIRST
```bash
# Node/Next.js
cat package.json | grep -E "pino|winston|opentelemetry|@sentry|datadog|newrelic|dd-trace|prometheus"
# Python
cat requirements.txt | grep -E "opentelemetry|structlog|loguru|sentry-sdk|prometheus"
# Flutter
cat pubspec.yaml | grep -E "sentry_flutter|firebase_crashlytics|datadog_flutter"
# Infra
ls docker-compose.yml docker-compose.monitoring.yml prometheus.yml 2>/dev/null
```

---

## THE THREE PILLARS

| Pillar | Tool | When to load |
|--------|------|-------------|
| **Logs** | Pino (Node) · structlog (Python) · structured JSON | Always |
| **Traces** | OpenTelemetry → Jaeger / Tempo | Distributed services, latency hunts |
| **Metrics** | Prometheus + Grafana | Throughput, error rate, saturation |

**Rule:** Logs tell you WHAT. Traces tell you WHERE. Metrics tell you WHEN.

---

## STRUCTURED LOGGING

### Node.js — Pino (fastest)
```typescript
import pino from 'pino';

export const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  // In production: JSON. In dev: pretty
  transport: process.env.NODE_ENV === 'development'
    ? { target: 'pino-pretty', options: { colorize: true } }
    : undefined,
  redact: ['req.headers.authorization', 'body.password', 'body.token'],
  base: { service: process.env.SERVICE_NAME ?? 'app' },
});

// Always: structured fields, never string concat
logger.info({ userId, action: 'login', ip: req.ip }, 'User authenticated');
// Never: logger.info(`User ${email} logged in`) ← unqueryable, leaks PII
```

### Next.js — per-request context
```typescript
// lib/logger.ts
import { AsyncLocalStorage } from 'node:async_hooks';

const requestContext = new AsyncLocalStorage<{ traceId: string; userId?: string }>();

export const withRequestContext = (traceId: string, fn: () => Promise<void>) =>
  requestContext.run({ traceId }, fn);

export const log = {
  info: (msg: string, fields?: object) =>
    logger.info({ ...requestContext.getStore(), ...fields }, msg),
  error: (msg: string, err: unknown, fields?: object) =>
    logger.error({ ...requestContext.getStore(), ...fields, err }, msg),
  warn: (msg: string, fields?: object) =>
    logger.warn({ ...requestContext.getStore(), ...fields }, msg),
};
```

### Python — structlog
```python
import structlog

log = structlog.get_logger()

structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer(),  # prod
    ]
)

# Usage
log.info("user.authenticated", user_id=user_id, ip=request.client.host)
log.error("payment.failed", order_id=order_id, reason=str(exc), exc_info=True)
```

---

## OPENTELEMETRY — Distributed Tracing

### Node.js setup (instrument before any import)
```typescript
// instrumentation.ts — MUST be loaded first (Node --require flag)
import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { Resource } from '@opentelemetry/resources';
import { SEMRESATTRS_SERVICE_NAME } from '@opentelemetry/semantic-conventions';

const sdk = new NodeSDK({
  resource: new Resource({ [SEMRESATTRS_SERVICE_NAME]: process.env.SERVICE_NAME }),
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT ?? 'http://jaeger:4318/v1/traces',
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
process.on('SIGTERM', () => sdk.shutdown());
```

### Manual span (critical paths)
```typescript
import { trace, SpanStatusCode } from '@opentelemetry/api';

const tracer = trace.getTracer('my-service');

async function processOrder(orderId: string) {
  return tracer.startActiveSpan('process-order', async (span) => {
    span.setAttribute('order.id', orderId);
    try {
      const result = await doWork(orderId);
      span.setStatus({ code: SpanStatusCode.OK });
      return result;
    } catch (err) {
      span.setStatus({ code: SpanStatusCode.ERROR, message: String(err) });
      span.recordException(err as Error);
      throw err;
    } finally {
      span.end();
    }
  });
}
```

---

## PROMETHEUS METRICS — Node.js

```typescript
import { Registry, Counter, Histogram, Gauge } from 'prom-client';

export const registry = new Registry();

export const httpRequestsTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [registry],
});

export const httpDurationSeconds = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
  registers: [registry],
});

export const activeConnections = new Gauge({
  name: 'active_websocket_connections',
  help: 'Active WebSocket connections',
  registers: [registry],
});

// Express/Hono middleware
app.use((req, res, next) => {
  const end = httpDurationSeconds.startTimer({ method: req.method, route: req.route?.path });
  res.on('finish', () => {
    const labels = { method: req.method, route: req.route?.path ?? 'unknown', status_code: res.statusCode };
    httpRequestsTotal.inc(labels);
    end(labels);
  });
  next();
});

// Metrics endpoint — internal only, never public
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', registry.contentType);
  res.end(await registry.metrics());
});
```

---

## FLUTTER — Crash Reporting + Performance

```yaml
# pubspec.yaml
dependencies:
  sentry_flutter: ^8.0.0
  # OR
  firebase_crashlytics: ^4.0.0
```

```dart
// main.dart — Sentry
Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment('SENTRY_DSN');
      options.tracesSampleRate = kReleaseMode ? 0.2 : 1.0;
      options.profilesSampleRate = 0.1;
      options.environment = kReleaseMode ? 'production' : 'development';
      options.attachScreenshot = true;
      options.attachViewHierarchy = true;
    },
    appRunner: () => runApp(const MyApp()),
  );
}

// Capture errors not caught by Flutter
FlutterError.onError = (FlutterErrorDetails details) {
  Sentry.captureException(details.exception, stackTrace: details.stack);
};

// Manual capture
try {
  await riskyOperation();
} catch (e, stack) {
  await Sentry.captureException(e, stackTrace: stack,
      withScope: (scope) => scope.setTag('feature', 'checkout'));
  rethrow;
}

// Performance span
final transaction = Sentry.startTransaction('checkout', 'task');
try {
  await processPayment();
  transaction.status = SpanStatus.ok();
} catch (e) {
  transaction.throwable = e;
  transaction.status = SpanStatus.internalError();
} finally {
  await transaction.finish();
}
```

---

## GRAFANA DASHBOARD — Essential Panels

```yaml
# RED Method — every service should expose these
panels:
  - title: "Request Rate"
    query: "rate(http_requests_total[5m])"
  - title: "Error Rate"
    query: "rate(http_requests_total{status_code=~'5..'}[5m]) / rate(http_requests_total[5m])"
  - title: "P99 Latency"
    query: "histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))"
  - title: "P95 Latency"
    query: "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"

# USE Method — for infrastructure
  - title: "CPU Utilization"
    query: "rate(container_cpu_usage_seconds_total[5m])"
  - title: "Memory Saturation"
    query: "container_memory_usage_bytes / container_spec_memory_limit_bytes"
```

---

## ALERTING — Prometheus AlertManager rules

```yaml
# alerts.yml
groups:
  - name: service-health
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status_code=~"5.."}[5m]) > 0.05
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Error rate >5% on {{ $labels.service }}"

      - alert: HighLatencyP99
        expr: histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m])) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "P99 latency >2s on {{ $labels.service }}"

      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "{{ $labels.job }} is down"
```

---

## DOCKER COMPOSE — Monitoring Stack

```yaml
# docker-compose.monitoring.yml
services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    command: ['--config.file=/etc/prometheus/prometheus.yml', '--storage.tsdb.retention.time=15d']
    ports: ["9090:9090"]

  grafana:
    image: grafana/grafana:latest
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards:ro
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD}
      GF_AUTH_ANONYMOUS_ENABLED: "false"
    ports: ["3000:3000"]

  jaeger:
    image: jaegertracing/all-in-one:latest
    environment:
      COLLECTOR_OTLP_ENABLED: "true"
    ports: ["16686:16686", "4318:4318"]

volumes:
  prometheus_data:
  grafana_data:
```

---

## ANTI-PATTERNS

| Pattern | Problem | Fix |
|---------|---------|-----|
| `console.log("user:", user)` | Logs PII, unstructured, no queryability | `log.info("user.action", { userId: user.id })` |
| `catch (e) { /* silent */ }` | Error swallowed, invisible in prod | Always log + optionally rethrow |
| Log level `debug` in prod | Floods log ingestion, costs money | Default `info` prod, `debug` local only |
| No trace IDs | Can't correlate across services | Inject `x-trace-id` header, propagate everywhere |
| Alert on every metric spike | Alert fatigue → ignored alerts | Alert on user-visible impact (error rate, latency) |
| Log full request body | PII leak, secrets in logs | Redact sensitive fields in logger config |
