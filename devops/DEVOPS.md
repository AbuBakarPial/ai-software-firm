# DEVOPS DIRECTIVE · v2026.10
> Full CI/CD · Docker · Nginx · Monitoring · GitLab/GitHub Actions
>
> **Pair with:** `DEVOPS_SKILL.md` for full CI pipeline YAML templates.
> **Team files:** `shared/AGENT_GOD_MODE.md` (universal) + this file + `DEVOPS_SKILL.md`.

---

## DETECT FIRST
```bash
ls .gitlab-ci.yml .github/workflows/ Dockerfile docker-compose*.yml 2>/dev/null
cat docker-compose.yml 2>/dev/null | grep -E "image:|build:" | head -10
```

---

## CI/CD — GITLAB (adapt for GitHub Actions)

```yaml
# .gitlab-ci.yml
stages: [lint, test, build, security, deploy]

variables:
  DOCKER_BUILDKIT: "1"
  IMAGE: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA

.rules-mr: &rules-mr
  rules: [{ if: '$CI_PIPELINE_SOURCE == "merge_request_event"' }]
.rules-main: &rules-main
  rules: [{ if: '$CI_COMMIT_BRANCH == "main"' }]

lint:
  <<: *rules-mr
  image: dart:stable
  script: [dart format --check ., dart analyze --fatal-warnings]

test:
  <<: *rules-mr
  image: ghcr.io/cirruslabs/flutter:stable
  script:
    - flutter pub get
    - flutter test --coverage
    - dart pub global activate coverage
    - dart pub global run coverage:format_coverage --lcov --in=coverage --out=lcov.info
  coverage: '/lines\.*:\s(\d+.\d+\%)/'
  artifacts:
    reports: { coverage_report: { coverage_format: cobertura, path: coverage/cobertura.xml } }

build-android:
  <<: *rules-main
  image: ghcr.io/cirruslabs/flutter:stable
  script:
    - flutter pub get
    - flutter build apk --release --dart-define=ENV=production
      --dart-define=SUPABASE_URL=$SUPABASE_URL
      --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
  artifacts: { paths: [build/app/outputs/flutter-apk/app-release.apk] }

security-scan:
  <<: *rules-main
  image: aquasec/trivy:latest
  script:
    - trivy fs --exit-code 1 --severity HIGH,CRITICAL .
    - trivy config --exit-code 1 --severity HIGH,CRITICAL .
  allow_failure: false

deploy-staging:
  <<: *rules-main
  environment: staging
  script:
    - docker build -t $IMAGE .
    - docker push $IMAGE
    - docker-compose -f docker-compose.staging.yml up -d
  needs: [build-android, security-scan]

deploy-prod:
  <<: *rules-main
  environment: production
  when: manual    # human approves
  script: [./scripts/deploy-prod.sh]
  needs: [deploy-staging]
```

---

## GITHUB ACTIONS (web projects)

```yaml
# .github/workflows/ci.yml
name: CI
on:
  push: { branches: [main] }
  pull_request: { branches: [main] }

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci
      - run: npm run lint
      - run: npm test -- --coverage
      - run: npm run build

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aquasecurity/trivy-action@master
        with: { scan-type: 'fs', severity: 'HIGH,CRITICAL', exit-code: '1' }

  deploy:
    needs: [test, security]
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/deploy.sh
```

---

## DOCKER

```dockerfile
# Multi-stage — minimal final image
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json .
RUN npm ci --only=production

FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules .
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN addgroup --system --gid 1001 nodejs && adduser --system --uid 1001 nextjs
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone .
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
USER nextjs
EXPOSE 3000
CMD ["node", "server.js"]
```

---

## NGINX + SSL

```nginx
# /etc/nginx/sites-available/app
server {
    listen 80; server_name yourdomain.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com;

    ssl_certificate     /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    ssl_session_cache   shared:SSL:10m;

    # Security headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;
    add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'nonce-$request_id'; style-src 'self' 'unsafe-inline'" always;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=100r/m;
    limit_req_zone $binary_remote_addr zone=auth:10m rate=5r/m;

    location /api/auth { limit_req zone=auth burst=3 nodelay; proxy_pass http://app:3000; }
    location /api/     { limit_req zone=api burst=20 nodelay; proxy_pass http://app:3000; }
    location /         { proxy_pass http://app:3000; proxy_set_header Host $host; proxy_set_header X-Real-IP $remote_addr; }

    # WebSocket support
    location /ws {
        proxy_pass http://app:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

---

## MONITORING

```yaml
# docker-compose monitoring stack
services:
  prometheus:
    image: prom/prometheus:latest
    volumes: [./prometheus.yml:/etc/prometheus/prometheus.yml]
    ports: ['9090:9090']

  grafana:
    image: grafana/grafana:latest
    ports: ['3001:3000']
    environment: { GF_SECURITY_ADMIN_PASSWORD: $GRAFANA_PASSWORD }

  loki:
    image: grafana/loki:latest
    ports: ['3100:3100']

  # Error tracking
  glitchtip:
    image: glitchtip/glitchtip
    environment:
      DATABASE_URL: $GLITCHTIP_DB_URL
      SECRET_KEY: $GLITCHTIP_SECRET
```

---

## BACKUP (Postgres)
```bash
#!/bin/bash
# backup.sh — run via cron: 0 2 * * * /opt/scripts/backup.sh
set -euo pipefail
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/backups/db_$TIMESTAMP.sql.gz"
pg_dump $DATABASE_URL | gzip > $BACKUP_FILE
# Upload to S3/object storage
aws s3 cp $BACKUP_FILE s3://$BACKUP_BUCKET/postgres/
# Delete local backups older than 7 days
find /backups -name "*.sql.gz" -mtime +7 -delete
echo "Backup complete: $BACKUP_FILE"
```

---

## PRODUCTION CHECKLIST
- [ ] SSL certificate valid + auto-renew (certbot)
- [ ] All secrets in env vars — none in code or Docker image
- [ ] Nginx rate limiting on auth routes
- [ ] Security headers set (HSTS, CSP, X-Frame)
- [ ] DB backups scheduled + tested (restore drill)
- [ ] Monitoring + alerting live (Prometheus/Grafana)
- [ ] Error tracking live (GlitchTip/Sentry)
- [ ] Container images scanned (Trivy)
- [ ] CI/CD pipeline: lint → test → security → build → deploy
- [ ] Manual approval gate before production deploy
- [ ] Rollback procedure tested
