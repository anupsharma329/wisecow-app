# AccuKnox DevOps Trainee Assessment – Wisecow (Single README)

This repository demonstrates containerization, Kubernetes deployment, CI/CD, TLS, and zero‑trust runtime hardening (KubeArmor) for the Wisecow app.

## What’s included
- Dockerfile and app script (`wisecow.sh`)
- Kubernetes manifests (`k8s/`): namespace, configmap, deployment (3 replicas), services, ingress, TLS
- GitHub Actions workflow (`.github/workflows/ci-cd.yaml`)
- KubeArmor zero‑trust policy (`k8s/kubearmor/wisecow-enhanced-zero-trust.yaml`)
- Monitoring scripts (`monitoring/`) for PS2

## Quick start
```bash
# 1) Build & run locally
docker build -t wisecow-app .
docker run -p 4499:4499 wisecow-app

# 2) Deploy core K8s resources
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service-nodeport.yaml

# 3) Access
minikube service wisecow-service-nodeport -n wisecow --url || \
  kubectl -n wisecow port-forward svc/wisecow-service 8080:80
```

## CI/CD (GitHub Actions)
- On push to main: builds multi‑arch image, pushes to Docker Hub, updates `k8s/deployment.yaml` image tag.
- Optional direct deploy supported via workflow inputs.

## TLS (Challenge Goal)
```bash
# Let’s Encrypt style (production-like)
kubectl apply -f k8s/cluster-issuer.yaml
kubectl apply -f k8s/certificate.yaml
kubectl apply -f k8s/ingress.yaml
kubectl -n wisecow get ingress,certificate
```
For local TLS with self‑signed certs, you can adapt as needed.

## KubeArmor (Zero‑Trust Runtime)
Policy file: `k8s/kubearmor/wisecow-enhanced-zero-trust.yaml`
- Blocks: interactive shells (`/bin/sh`, `/bin/ash`, `/bin/busybox` as shell, etc.), ServiceAccount token reads, sensitive dirs, exfil tools (`curl`, `wget`, `ssh`, `scp`, `rsync`).
- Allows only app binaries: `/usr/bin/fortune`, `/usr/local/bin/cowsay` (Perl), `/usr/bin/nc`, plus basic utilities used by the app.

Apply and test (replace POD with an `app=wisecow` pod):
```bash
kubectl apply -f k8s/kubearmor/wisecow-enhanced-zero-trust.yaml
kubectl -n wisecow get ksp

# Negative (expect denied)
kubectl -n wisecow exec POD -- /bin/sh -c 'id'
kubectl -n wisecow exec POD -- /bin/cat /var/run/secrets/kubernetes.io/serviceaccount/token

# Positive (expect allowed)
kubectl -n wisecow exec POD -- /usr/bin/fortune
kubectl -n wisecow exec POD -- /usr/local/bin/cowsay hello
kubectl -n wisecow exec POD -- /usr/bin/nc -z localhost 4499 && echo listening
```

## PS2 Scripts (two objectives)
- System Health Monitoring: `monitoring/system-monitor.sh` (CPU/mem/disk/process thresholds -> alerts)
- Application Health Checker: `monitoring/simple-health-check.sh <URL>` (HTTP status -> UP/DOWN)

## Reviewer checklist
- Docker image builds and runs locally.
- K8s deploys 3 replicas, Service exposes app.
- CI builds and updates image tag.
- TLS ingress works (Let’s Encrypt or local adaptation).
- KubeArmor policy enforced: shells/token blocked; app binaries allowed.
- PS2 scripts run and report correctly.