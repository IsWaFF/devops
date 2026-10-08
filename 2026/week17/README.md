# Week 17

## 5 october

k8s: day 9. configmaps

example

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: podinfo-config
data:
  PODINFO_UI_MESSAGE: "Hello from a ConfigMap"
  PODINFO_UI_COLOR: "#ff5e00ff"
```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: demo-file
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Dima's lab</title></head>
    <body>
    <h1>This page lives in a ConfigMap</h1>
    <p>Delete the Pod, and the page is still here.</p>
    </body>
    </html>
```

### ConfigMap - environment variables

```yaml
envFrom:
  - configMapRef:
      name: podinfo-config
```

- every key becomes an env var
- configmap changed -> running pods still see the old values, env is read only on start: `kubectl rollout restart deployment podinfo`
- configmap doesn't exist -> pod is stuck in `CreateContainerConfigError`

### ConfigMap - files (volume)

```yaml
      volumeMounts:
        - name: config
          mountPath: /usr/share/nginx/html
  volumes:
    - name: config
      configMap:
        name: site
```

- every key becomes a file in `mountPath`
- configmap changed -> files update by themselves (~1 min), but the app may need a reload
- mount replaces the whole dir: `/etc/nginx` instead of `/etc/nginx/conf.d` -> `nginx.conf` is gone and nginx crashes

`kubectl create configmap site --from-file=index.html` - make a configmap from a file

## 6 october

k8s: day 10. secrets

example

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-auth
type: Opaque
stringData:
  username: shop
  password: k8s-is-fun-2026
```

- `data` - values must be base64, plain text -> `illegal base64 data` on apply
- `stringData` - plain text, k8s encodes it by itself
- base64 is NOT encryption, anyone with `get secret` can read it -> never commit real secrets to git

`kubectl create secret generic api-key --from-literal=token=abc123` - make a secret without a yaml file

`kubectl get secret db-auth -o jsonpath='{.data.password}' | base64 -d` - read a value back

### Secret - environment variables

```yaml
env:
  - name: PGPASSWORD
    valueFrom:
      secretKeyRef:
        name: db-auth
        key: password
```

- same rules as configmap: read only on start, secret doesn't exist -> `CreateContainerConfigError`
- env leaks easily: `kubectl describe`, `env` in a shell, crash dumps, logs

### Secret - files (volume)

```yaml
      volumeMounts:
        - name: db-auth
          mountPath: /run/secrets/db
          readOnly: true
  volumes:
    - name: db-auth
      secret:
        secretName: db-auth
```

- every key becomes a file: `/run/secrets/db/password`
- many images can read a secret from a file: `POSTGRES_PASSWORD_FILE=/run/secrets/db/password`
- files update by themselves, like a configmap

### Gotchas (fixme)

- `echo 'pass' | base64` adds `\n` to the value -> password is wrong, login fails. use `echo -n` or `stringData`
- a secret lives in a namespace, the pod can use only secrets from its own namespace

## 7 october

completed ["Geneva": Renew an SSL Certificate](https://sadservers.com/scenario/geneva), ~2h, 4 servers (3 timed out), 5 hints from claude

**key fixes and commands:**

- sudo nginx -T | grep ssl_certificate - nginx itself says where the cert and the key are: /etc/nginx/ssl/nginx.crt and nginx.key
- openssl x509 -in /etc/nginx/ssl/nginx.crt -noout -subject -dates - subject `CN = localhost, O = Acme, OU = IT Department, L = Geneva, ST = Geneva, C = CH`, notAfter feb 29 2024
- openssl version - 1.1.1w, old one
- echo | openssl s_client -connect localhost:443 2>/dev/null | openssl x509 -noout -dates - what nginx really serves, not what's on disk

problem was an expired self-signed cert. the new one must have the same subject

**answer:**

```bash
cd /etc/nginx/ssl
sudo openssl req -x509 -newkey rsa:2048 -nodes -keyout nginx.key -out nginx.crt -days 366 -subj "/CN=localhost/O=Acme/OU=IT Department/L=Geneva/ST=Geneva/C=CH" -addext "subjectAltName=DNS:localhost"
sudo nginx -t && sudo nginx -s reload
```

then both test commands from the task -> new dates, same subject

my mistakes:

- looked for the cert in /etc/ca-certificates and /etc/ssl/certs. that's the trust store (root CAs), not the site cert. ask the program that uses the cert (nginx -T), don't guess dirs
- failed openssl command left nginx.key empty (0 bytes). backup before replacing
- copied -subj from the cheatsheet (only CN) instead of checking the task
- pasted subject the way openssl prints it (`CN = localhost, O = Acme`) -> `Skipping unknown attribute "CN "`
- forgot L and ST, pressed Check without running the test commands

### tls cert

- subject - who the cert is for, issuer - who signed it. self-signed -> subject = issuer
- -subj format: every field starts with /, no spaces around =, no commas
- `-noenc` is openssl 3, in 1.1.1 it's `-nodes`. without it the key gets a passphrase and nginx asks for it on start
- nginx reads certs only on start/reload. new file on disk != new cert for clients
- nginx -s reload only sends a signal, a broken config fails silently -> nginx -t first

## 8 october

k8s: day 11. probes

example

```yaml
          readinessProbe:          # "can I send traffic to you?"
            httpGet:
              path: /readyz
              port: http
            periodSeconds: 3
          livenessProbe:           # "are you still alive?"
            httpGet:
              path: /healthz
              port: http
            periodSeconds: 10
```

- readiness fails -> pod is removed from service endpoints, NOT restarted. rollout waits for it
- liveness fails -> kubelet restarts the container
- startup -> liveness and readiness are off until it passes. for slow apps
- `httpGet` - 200-399 is ok, `exec` - exit code 0 is ok
- `port: http` is a name -> it must exist in `ports:` of the container

### startup probe

```yaml
          startupProbe:
            httpGet:
              path: /
              port: http
            periodSeconds: 5
            failureThreshold: 12   # 12 x 5s = up to 60s to start
```

- time to start = failureThreshold x periodSeconds, no big initialDelaySeconds

### Gotchas (fixme)

- `port "http" not found` -> probe errored, not failed -> kubelet ignores it, 0 restarts. 0 restarts != probe works, check events
- default `timeoutSeconds` is 1s -> `/delay/2` always times out -> healthy app restarts forever. fix: `timeoutSeconds: 3`
- readiness on a wrong port (9999) -> pods `Running 0/1`, service has no endpoints
- liveness checks only the app itself. another service in liveness -> it goes down = all pods restart, restart doesn't fix it
- `curl` without `-f` returns 0 on 404/500 -> exec probe is always green

## 9 october

k8s: day 12. resources

example

```yaml
      resources:
        requests:            # "I need at least this much", for the scheduler
          cpu: "250m"
          memory: "64Mi"
        limits:              # "never more than this", the kernel (cgroups) enforces it
          cpu: "500m"
          memory: "128Mi"
```

- cpu is in cores: `1` = one core, `500m` = half a core (`m` = millicores)
- memory: `64Mi` = 64 x 1024 x 1024, `64M` = 64 x 1000 x 1000. use `Mi`/`Gi`
- `cpu: 400mi` -> `unable to parse quantity's suffix`. cpu has only `m`, `i` is for memory
- `Gi` instead of `Mi` is the classic typo, one letter = 1024x more

### requests are for the scheduler

- scheduler looks only at requests, not at real usage: a node fits if allocatable - already requested >= my requests
- nothing fits -> pod is `Pending` forever, event `FailedScheduling ... Insufficient cpu`
- `kubectl describe node lab-worker | grep -A 6 '^Allocated resources'` - how much is already requested on a node
- kind nodes see the whole laptop (12 cpu), on real servers every node has its own
- `big`: 5 cpu per pod, 12 cpu per worker -> 2 pods per worker, control-plane has a taint -> 5 replicas = 4 `Running` + 1 `Pending`. idle pods, but requests decide

### over the limit

- memory over the limit -> kernel kills it: `OOMKilled`, exit code 137 (128 + 9 = SIGKILL) -> restart -> `CrashLoopBackOff`
- exit code 137 -> check OOMKilled first
- the app has no time to log "out of memory", logs just stop in the middle
- files in `/dev/shm` (tmpfs) count as memory
- `kubectl get pod memhog -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'` -> `OOMKilled`
- cpu over the limit -> not killed, throttled: pod stays `Running`, just slow (slow responses, not crashes)
- `kubectl exec cpuhog -- cat /sys/fs/cgroup/cpu.max` -> `20000 100000` = 20% of a core = `200m`. `cpu.stat`: `nr_throttled` ~ `nr_periods`

### QoS classes

node is out of memory -> kubelet evicts pods: BestEffort first, Guaranteed last

- `Guaranteed` - every container has requests = limits, for cpu AND memory. only limits set -> k8s copies them into requests -> also Guaranteed
- `Burstable` - some requests/limits, but not Guaranteed
- `BestEffort` - nothing at all. all my pods before day 12 were this

`kubectl get pod guaranteed -o jsonpath='{.status.qosClass}'`

### LimitRange and ResourceQuota

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: defaults
  namespace: team-a
spec:
  limits:
    - type: Container
      defaultRequest:        # container has no requests -> these
        cpu: "100m"
        memory: "64Mi"
      default:               # container has no limits -> these
        cpu: "200m"
        memory: "128Mi"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-a-quota
  namespace: team-a
spec:
  hard:
    pods: "3"
    requests.cpu: "1"         # sum of cpu requests of all pods in the namespace
    requests.memory: "512Mi"
```

- LimitRange - per container: defaults, min/max
- ResourceQuota - total for the whole namespace: number of pods, sum of requests/limits
- both are checked on create (admission). over the quota -> `Forbidden: exceeded quota`, the pod never exists. running pods are not touched
- quota on `requests.cpu`/`requests.memory`/`limits.memory` -> every pod MUST set them, or `must specify ...`. a LimitRange with defaults fixes it
- `kubectl describe resourcequota -n team-a` - Used / Hard

### what to set

- always set requests (cpu and memory), otherwise BestEffort
- memory limit = memory request (or a bit more)
- cpu limit is optional, it throttles even when the node is idle
- measure, don't guess: `kubectl top` (day 25)

### Gotchas (fixme)

- `64Gi` instead of `64Mi` -> `Pending`, `Insufficient memory`, the pod asks for more than the whole laptop
- limit 32Mi, app loads 60MB into `/dev/shm` -> `OOMKilled`, logs stop after `loading 60 MB...`. fix: bigger limit (128Mi), but first check it's not a leak
- deployment `0/2`, no pods, no events on the deployment -> the error is one level down: `kubectl describe rs -n billing` -> `failed quota: billing-quota: must specify limits.memory ...`. fix: add resources to the template (or a LimitRange). deployment -> replicaset -> pod
