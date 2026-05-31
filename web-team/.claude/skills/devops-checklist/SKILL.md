# SKILL: DevOps · Web · v2026.9
> Load when: deployment, CI/CD, infra changes.

## CI PIPELINE ORDER
```yaml
# validate → security → test → build → deploy
jobs:
  validate: { run: 'tsc --noEmit && eslint . --max-warnings 0' }
  security: { run: 'gitleaks detect && npm audit --audit-level high' }
  test:     { run: 'vitest run --coverage && playwright test' }
  build:    { run: 'next build' }
  deploy:   { needs: [validate, security, test, build] }
```

## PRODUCTION CHECKLIST
- [ ] `next build` → 0 errors
- [ ] TypeScript: 0 errors strict mode
- [ ] Bundle budget not exceeded (set in next.config.js)
- [ ] All env vars in target environment (not .env files)
- [ ] DB migrations run before app deployment
- [ ] Error tracking receiving events (Sentry/GlitchTip)
- [ ] Lighthouse: Performance ≥90, A11y ≥95, SEO ≥95
- [ ] Security headers verified: securityheaders.com

## ROLLBACK: git revert + redeploy. Target RTO < 5 minutes.
