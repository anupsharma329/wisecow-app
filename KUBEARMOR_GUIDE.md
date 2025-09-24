## KubeArmor hardening for wisecow

This guide documents the KubeArmor zero‑trust policies applied to the `wisecow` workload, why they exist, and how to test them.

### Overview
- Namespace: `wisecow`
- Target pods: label `app=wisecow`
- Policy file: `k8s/kubearmor/wisecow-enhanced-zero-trust.yaml`
- Enforcement: KubeArmor runs in Enforcer mode on the Minikube node

### What the policies do
1) Block shells (process rules)
   - Denies interactive shells and BusyBox used as a shell inside pods.
   - Blocked paths: `/bin/sh`, `/usr/bin/sh`, `/bin/bash`, `/usr/bin/bash`, `/bin/dash`, `/usr/bin/dash`, `/bin/ash`, `/usr/bin/ash`, `/bin/zsh`, `/usr/bin/zsh`, `/bin/busybox`.

2) Block access to Kubernetes ServiceAccount credentials (file rules)
   - Denies reads under `/var/run/secrets/kubernetes.io/serviceaccount/` including `token`, `ca.crt`, `namespace`.

3) Protect system directories (file rules)
   - Denies access to sensitive directories: `/root/`, `/var/lib/`, `/etc/`, `/sys/`, `/proc/sys/`, `/boot/`.

4) Block common network exfiltration tools (process rules)
   - Denies execution of: `/usr/bin/wget`, `/usr/bin/curl`, `/usr/bin/ssh`, `/usr/bin/scp`, `/usr/bin/rsync`.

5) Allow legitimate app processes (allow‑list)
   - App needs `fortune`, `cowsay` (Perl), healthcheck via `nc`, and basic utilities.
   - Allowed paths include: `/usr/bin/fortune`, `/usr/local/bin/cowsay`, `/usr/bin/perl`, `/usr/bin/nc`, `/bin/nc`, `/bin/ps`, `/usr/bin/ps`, `/bin/ls`, `/usr/bin/ls`, `/bin/cat`, `/usr/bin/cat`, `/bin/echo`, `/usr/bin/echo`, `/usr/bin/whoami`, `/bin/sleep`, `/usr/bin/sleep`.
   - BusyBox is allowed only when spawned by the entrypoint (`/bin/bash` → `/app/wisecow.sh`) to keep the app working but block interactive shells.

### Why these changes were needed
- The app `wisecow.sh` uses `nc` to listen on port 4499 and calls `fortune` and `cowsay` (Perl). Initial broad blocks caused permission errors for these binaries. We tightened the policy to:
  - Allow only the exact binaries the app needs.
  - Keep shells, SA token, and exfil tools blocked.
  - Handle Alpine’s BusyBox shell explicitly.

### Apply policies
```bash
kubectl apply -f k8s/kubearmor/wisecow-enhanced-zero-trust.yaml
kubectl -n wisecow get ksp
```

Ensure KubeArmor is enforcing
```bash
kubectl -n kubearmor get pods -o wide
# Find the daemon pod (e.g., kubearmor-xxxxx)
kubectl -n kubearmor logs <kubearmor-daemon-pod> --tail=200
kubectl -n kubearmor exec <kubearmor-daemon-pod> -- cat /sys/kernel/security/lsm  # should include bpf or apparmor
```

If needed, force Enforcer mode
```bash
cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: kubearmor-config
  namespace: kubearmor
data:
  operationMode: "enforcer"
YAML
kubectl -n kubearmor rollout restart ds/kubearmor
kubectl -n kubearmor rollout status ds/kubearmor
```

### Test enforcement on a wisecow pod
Replace POD with an `app=wisecow` pod (e.g., `wisecow-deployment-...`).

- Shells (blocked)
```bash
kubectl -n wisecow exec POD -- /bin/sh -c 'id'
kubectl -n wisecow exec POD -- /bin/ash -c 'id'
kubectl -n wisecow exec POD -- /bin/busybox sh -c 'id'
```

- ServiceAccount token (blocked)
```bash
kubectl -n wisecow exec POD -- /bin/cat /var/run/secrets/kubernetes.io/serviceaccount/token
```

- Network tools (blocked or not present)
```bash
kubectl -n wisecow exec POD -- which curl || echo "curl not present"
kubectl -n wisecow exec POD -- which wget || echo "wget not present"
kubectl -n wisecow exec POD -- curl -s https://example.com
kubectl -n wisecow exec POD -- wget -qO- https://example.com
```

- Application‑specific (allowed)
```bash
kubectl -n wisecow exec POD -- /usr/bin/fortune
kubectl -n wisecow exec POD -- /usr/local/bin/cowsay hello
kubectl -n wisecow exec POD -- /usr/bin/nc -z localhost 4499 && echo "listening" || echo "not listening"
kubectl -n wisecow exec POD -- /usr/bin/whoami
kubectl -n wisecow exec POD -- /bin/echo ok
```

Observe KubeArmor decisions (optional)
```bash
kubectl -n kubearmor logs <kubearmor-daemon-pod> --since=5m | grep -E 'wisecow|POD'
```

### Troubleshooting
- Shell not blocked: ensure `/bin/busybox` is included in the shell Block list; confirm Enforcer mode and LSM (`bpf` or `apparmor`) support.
- App fails to start: ensure allow‑list includes the exact paths used by the image (`/usr/bin/fortune`, `/usr/local/bin/cowsay`, `/usr/bin/perl`, `/usr/bin/nc`).
- Token read not blocked: verify token mount path and that the directory rule includes `recursive: true`.

### Cleanup
```bash
kubectl -n wisecow delete ksp --all   # removes all wisecow policies (if needed)
```


