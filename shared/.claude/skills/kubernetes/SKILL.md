# SKILL: Kubernetes · v2026.10
> Load when: deploying to Kubernetes, writing manifests, or troubleshooting K8s.
> Covers: Deployments, Services, Ingress, Helm, scaling, monitoring, RBAC

## DETECT FIRST
```bash
ls k8s/ kubernetes/ helm/ manifests/ 2>/dev/null
ls *.yaml | head -10
grep -r "apiVersion: apps/v1\|kind: Deployment\|kind: Service" . --include="*.yaml" -l | head -5
cat helm/Chart.yaml 2>/dev/null
kubectl config current-context 2>/dev/null || echo "No kube context"
```

---

## CORE RESOURCES

### Deployment (stateless apps)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  labels: { app: api, env: prod }
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate: { maxUnavailable: 0, maxSurge: 1 }
  selector: { matchLabels: { app: api } }
  template:
    metadata: { labels: { app: api } }
    spec:
      containers:
        - name: api
          image: registry/app:1.2.0
          ports: [{ containerPort: 3000, protocol: TCP }]
          envFrom: [{ secretRef: { name: api-secrets } }]
          resources:
            requests: { cpu: 100m, memory: 128Mi }
            limits:   { cpu: 500m, memory: 256Mi }
          livenessProbe:  { httpGet: { path: /health, port: 3000 }, initialDelaySeconds: 10 }
          readinessProbe: { httpGet: { path: /ready, port: 3000 }, initialDelaySeconds: 5 }
      securityContext: { runAsNonRoot: true, runAsUser: 1001 }
```

### Service (internal networking)
```yaml
apiVersion: v1
kind: Service
metadata: { name: api, labels: { app: api } }
spec:
  selector: { app: api }
  ports: [{ port: 80, targetPort: 3000, protocol: TCP }]
  type: ClusterIP  # Internal only. Use Ingress for external.
```

### Ingress (external traffic → Service)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/rate-limit: "100r/m"
spec:
  ingressClassName: nginx
  tls:
    - hosts: [api.yourdomain.com]
      secretName: api-tls
  rules:
    - host: api.yourdomain.com
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend: { service: { name: api, port: { number: 80 } } }
```

### ConfigMap (non-sensitive config)
```yaml
apiVersion: v1
kind: ConfigMap
metadata: { name: app-config }
data:
  NODE_ENV: production
  LOG_LEVEL: info
  # Mount as env vars or volume
```

### Secret (sensitive data — base64, encrypt at rest)
```yaml
apiVersion: v1
kind: Secret
metadata: { name: api-secrets }
type: Opaque
stringData:  # Use stringData (not data) for plaintext in source
  DATABASE_URL: postgresql://user:pass@db:5432/app
  JWT_SECRET: your-secret-here
```

### PersistentVolumeClaim (stateful storage)
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: data-pvc }
spec:
  accessModes: [ReadWriteOnce]
  resources: { requests: { storage: 10Gi } }
  storageClassName: standard
```

---

## HELM (package manager)

### Chart structure
```
my-chart/
├── Chart.yaml          # metadata: name, version, dependencies
├── values.yaml         # default config values
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── _helpers.tpl    # template helpers
│   └── tests/          # test templates
└── charts/             # subcharts (dependencies)
```

### values.yaml
```yaml
replicaCount: 3
image:
  repository: registry/app
  tag: latest
  pullPolicy: Always
resources:
  requests: { cpu: 100m, memory: 128Mi }
  limits:   { cpu: 500m, memory: 256Mi }
ingress:
  enabled: true
  host: api.yourdomain.com
  tls: true
env:
  NODE_ENV: production
```

### Commands
```bash
# Install/upgrade
helm upgrade --install api ./helm/api --values ./helm/api/values-prod.yaml --namespace prod

# Rollback
helm rollback api 2 --namespace prod

# Template (dry-run, see rendered YAML)
helm template ./helm/api --values ./helm/api/values-prod.yaml

# List releases
helm list --all-namespaces
```

---

## SCALING

### Horizontal Pod Autoscaler
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: { name: api-hpa }
spec:
  scaleTargetRef: { apiVersion: apps/v1, kind: Deployment, name: api }
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource: { name: cpu, target: { type: Utilization, averageUtilization: 70 } }
    - type: Resource
      resource: { name: memory, target: { type: Utilization, averageUtilization: 80 } }
```

### Cluster Autoscaler (auto-adds/removes nodes)
```bash
# Cluster Autoscaler scales the node pool based on pending pods
# Requires cloud provider integration (EKS, GKE, AKS)
```

---

## MONITORING STACK

```yaml
# Prometheus + Grafana — standard stack
# Install: helm repo add prometheus-community && helm install prometheus prometheus-community/kube-prometheus-stack

# ServiceMonitor — Prometheus discovers your app
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata: { name: api-monitor }
spec:
  selector: { matchLabels: { app: api } }
  endpoints: [{ port: http, path: /metrics, interval: 15s }]
```

```yaml
# Grafana dashboard via ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-dashboard
  labels: { grafana_dashboard: "1" }
data:
  api-dashboard.json: |
    { "title": "API Dashboard", "panels": [...] }
```

---

## RBAC (access control)

```yaml
# ServiceAccount — identity for pods
apiVersion: v1
kind: ServiceAccount
metadata: { name: api-sa }

# Role — what you can do in a namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: { name: api-role }
rules:
  - apiGroups: [""]
    resources: ["pods", "services"]
    verbs: ["get", "list", "watch"]

# RoleBinding — bind role to sa
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: { name: api-rolebinding }
subjects: [ { kind: ServiceAccount, name: api-sa } ]
roleRef: { kind: Role, name: api-role, apiGroup: rbac.authorization.k8s.io }
```

---

## TROUBLESHOOTING

```bash
# Pod issues
kubectl get pods -n prod
kubectl describe pod api-5d4f7b8c6-abc12 -n prod
kubectl logs api-5d4f7b8c6-abc12 -n prod --tail=100
kubectl logs -l app=api -n prod --tail=100  # all pods matching label

# Exec into pod
kubectl exec -it api-5d4f7b8c6-abc12 -n prod -- /bin/sh

# Port forwarding (for debugging locally)
kubectl port-forward svc/api 3000:80 -n prod

# Check events
kubectl get events -n prod --sort-by='.lastTimestamp'

# Resource usage
kubectl top pods -n prod
kubectl top nodes
```

---

## PRODUCTION CHECKLIST

- [ ] Resource requests and limits on ALL containers
- [ ] Readiness + liveness probes on every service
- [ ] PodDisruptionBudget for >=2 replicas
- [ ] Network policies restricting pod-to-pod traffic
- [ ] Secrets encrypted at rest (KMS/SealedSecrets/External Secrets)
- [ ] HorizontalPodAutoscaler configured
- [ ] Ingress with TLS (cert-manager auto-renew)
- [ ] ServiceMonitor for Prometheus
- [ ] Grafana dashboards for key metrics
- [ ] Pod security context: runAsNonRoot, readOnlyRootFilesystem
- [ ] No privileged containers
- [ ] Resource quotas per namespace
- [ ] Backup of PersistentVolume data
