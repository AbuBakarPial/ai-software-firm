# RUNBOOK · Flutter + Supabase Operations
Version: 1.0.0 | Use this when something breaks in production.

---

## SECTION 1 · SUPABASE DOCKER DOWN

**Symptoms:** App shows "connection failed", auth stops working, realtime disconnects.

### Triage (< 2 min)
```bash
# Check container status
docker ps -a | grep supabase

# Check logs
docker-compose logs --tail=100 supabase-db
docker-compose logs --tail=100 supabase-auth
docker-compose logs --tail=100 supabase-realtime
```

### Fix: Container crashed, healthy before
```bash
cd /path/to/supabase-docker
docker-compose restart supabase-db
sleep 10
docker-compose restart supabase-auth supabase-realtime supabase-rest

# Verify
docker-compose ps  # all should show "Up"
curl http://localhost:8000/health  # should return 200
```

### Fix: OOM / disk full
```bash
df -h  # check disk
docker system prune -f  # clear unused images/containers (safe)

# If DB disk full — Postgres won't start
du -sh /var/lib/docker/volumes/supabase_*
# Extend volume or move old WAL files
```

### Fix: Port conflict
```bash
lsof -i :8000  # find what's using Supabase port
# Kill conflicting process, restart containers
```

### Escalation
- DB won't start after 3 restart attempts → restore from backup (Section 3)
- Logs show "database corruption" → stop writes immediately, restore backup

---

## SECTION 2 · REALTIME / WEBSOCKET DOWN

**Symptoms:** Messages not delivering, online presence broken, no updates.

```bash
# Check realtime service
docker-compose logs --tail=50 supabase-realtime

# Test websocket
wscat -c ws://localhost:4000/socket/websocket?vsn=2.0.0
# Should connect. If refused → realtime container down.

docker-compose restart supabase-realtime
```

**Flutter side — force reconnect:**
```dart
// Emergency: call this if realtime stuck
await supabase.removeAllChannels();
await Future.delayed(const Duration(seconds: 2));
// Re-subscribe channels
```

---

## SECTION 3 · DATABASE BACKUP + RESTORE

### Daily Backup (set this up now)
```bash
#!/bin/bash
# /opt/scripts/backup-supabase.sh
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/backups/supabase"
mkdir -p $BACKUP_DIR

docker exec supabase-db pg_dump \
  -U postgres \
  -Fc \
  --no-acl \
  --no-owner \
  postgres > "$BACKUP_DIR/supabase_$TIMESTAMP.dump"

# Keep 30 days
find $BACKUP_DIR -name "*.dump" -mtime +30 -delete

echo "Backup complete: supabase_$TIMESTAMP.dump"
```

```bash
# Cron — run daily at 2am
echo "0 2 * * * /opt/scripts/backup-supabase.sh" | crontab -
```

### Restore
```bash
# 1. Stop app (prevent writes during restore)
# 2. Identify backup file
ls -la /opt/backups/supabase/ | tail -5

# 3. Restore
BACKUP_FILE="/opt/backups/supabase/supabase_20260101_020000.dump"
docker exec -i supabase-db pg_restore \
  -U postgres \
  -d postgres \
  --clean \
  --no-acl \
  --no-owner \
  < $BACKUP_FILE

# 4. Verify
docker exec supabase-db psql -U postgres -c "SELECT count(*) FROM messages;"

# 5. Restart services
docker-compose restart
```

---

## SECTION 4 · DATABASE COMPROMISE

**If you suspect unauthorized DB access:**

```bash
# 1. IMMEDIATELY rotate service role key (Supabase dashboard or env)
# New key → update CI/CD variables → redeploy

# 2. Invalidate ALL active user sessions
docker exec supabase-db psql -U postgres -c \
  "DELETE FROM auth.sessions;"

# 3. Check recent auth.audit_log_entries
docker exec supabase-db psql -U postgres -c \
  "SELECT * FROM auth.audit_log_entries 
   WHERE created_at > NOW() - INTERVAL '72 hours'
   ORDER BY created_at DESC LIMIT 50;"

# 4. Check for unexpected superusers
docker exec supabase-db psql -U postgres -c \
  "SELECT usename, usesuper FROM pg_user WHERE usesuper = true;"

# 5. Lock down — restrict to office LAN immediately
# Update Nginx to whitelist office IP only
```

---

## SECTION 5 · CRYPTO KEY ROTATION (Rust FFI)

**Rotate session keys (routine, every 90 days):**
1. Generate new key material in secure environment
2. Deploy via encrypted CI/CD variable
3. Old keys: revoke after 24h grace period (in-flight sessions)
4. Update MEMORY.md with rotation date

**Emergency rotation (potential compromise):**
1. Generate new keys immediately
2. Deploy with zero grace period (force all re-auth)
3. Notify users: "Security update — please sign in again"
4. Document in ERRORS.md with incident timeline

---

## SECTION 6 · WEBRTC CALL FAILURE

**Symptoms:** Calls fail to connect, audio drops, one-way audio.

```bash
# Check TURN/STUN server (if self-hosted)
# Test TURN connectivity
turnutils_uclient -u testuser -w testpass turn:your-server:3478

# Check Supabase Realtime (signaling channel)
docker-compose logs --tail=50 supabase-realtime | grep -i "webrtc\|signal"
```

**Flutter debug:**
```dart
// Enable WebRTC verbose logging in dev
RTCSessionDescription? offer = await peerConnection.createOffer({
  'iceRestart': true, // force ICE restart on reconnect
});
```

**Common fix:** ICE candidate gathering timeout → check firewall allows UDP 49152-65535.

---

## SECTION 7 · GLITCHTIP / ERROR TRACKING DOWN

```bash
# Check GlitchTip containers
docker-compose -f glitchtip-compose.yml ps

# Restart
docker-compose -f glitchtip-compose.yml restart

# If Postgres (GlitchTip's own) is down
docker-compose -f glitchtip-compose.yml restart glitchtip-db
sleep 15
docker-compose -f glitchtip-compose.yml restart glitchtip-web glitchtip-worker
```

**Consequence of GlitchTip being down:** errors still occur in app, just not tracked. Not a user-visible outage. Fix within 24h.

---

## SECTION 8 · GITLAB CI/CD PIPELINE FAILURE

```bash
# Check runner status
gitlab-runner status

# Restart runner
sudo gitlab-runner restart

# Common: runner out of disk
df -h /var/lib/docker
docker system prune -f

# Common: Flutter version mismatch in CI
# Update .gitlab-ci.yml Flutter version to match local
```

---

## SECTION 9 · ROLLBACK PROCEDURE

**If a release breaks production:**

```bash
# 1. Identify last good build artifact in GitLab
# GitLab → CI/CD → Pipelines → find last green pipeline

# 2. Flutter app rollback — push previous tag
git checkout v1.2.3-stable
git push origin HEAD:main --force  # triggers CI rebuild

# 3. Supabase migrations rollback
# Migrations are append-only by default
# If destructive migration: restore from backup (Section 3)

# 4. Emergency: revert specific migration
docker exec supabase-db psql -U postgres -f /path/to/rollback-migration.sql
```

**Rollback decision tree:**
- P0 crash (app unusable) → rollback immediately, investigate after
- P1 feature broken → investigate first (< 30 min), then rollback if no fix
- P2 degraded performance → monitor, rollback if worsens

---

## SECTION 10 · ALERTING THRESHOLDS

Set these in GlitchTip:

| Event | Threshold | Action |
|-------|-----------|--------|
| Crash rate | > 1% of sessions | Immediate page |
| Auth errors | > 10/min | Investigate DB/network |
| WebSocket disconnects | > 20% of active users | Check Realtime container |
| Slow query | > 2s | Check Postgres indexes |
| Disk usage | > 80% | Schedule cleanup |
| Failed logins | > 50/min from one IP | Rate limit / block IP |

---

## SECTION 11 · OFFICE → HOME FAILOVER

**When working from home (no Supabase access):**

Verifiable from home (per DEPLOYMENT_STRATEGY.md Section 1):
- UI/UX and theming
- Unit tests: `flutter test` (all 48 controller tests with mocked repos)
- Build pipeline: `flutter build apk --debug`
- GlitchTip: run local Docker instance

Not verifiable from home — accept and move on. Don't attempt to tunnel into office network without VPN/WireGuard in place.

---

*Last updated: 2026.05. Review quarterly or after every incident.*
