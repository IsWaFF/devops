# week 18

## 12 october

k8s: day 13. pod lifecycle

example

```yaml
spec:
  initContainers:
    - name: prepare                     # runs first, must exit 0
      image: busybox:1.38
      command: ["sh", "-c"]
      args:
        - |
          echo "$HOSTNAME " > /tmp/index/index.html
          echo "$NODE" >> /tmp/index/index.html
      env:
        - name: NODE
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName   # downward api, node name is not an env by default
      volumeMounts:
        - mountPath: /tmp/index
          name: emptydir
  containers:
    - name: web                         # starts only after all init containers succeeded
      image: nginx:1.30-alpine
      volumeMounts:
        - mountPath: /usr/share/nginx/html
          name: emptydir
  volumes:
    - name: emptydir
      emptyDir: {}
```

- init containers run before app containers, one after another, each must exit 0. one fails -> app doesn't start
- use cases: wait for a dependency (`until nslookup ...`), prepare files, db migrations
- service exists != its pods are ready. `nslookup` only checks that the service is there
- `kubectl logs <pod> -c <container>` - logs of one container, init ones too

### volumes and emptyDir

- every container has its own filesystem, a file from one container is not visible in another -> volume
- `volumes:` once on pod level (name + type), `volumeMounts:` in every container that needs it (same name + its own mountPath)
- same files, different paths: `/tmp/index/index.html` in prepare = `/usr/share/nginx/html/index.html` in web
- emptyDir: created empty when the pod starts, survives container restarts, deleted with the pod
- volume name is a dns label: lowercase, digits, `-`. `emptyDir` as a name -> invalid. `emptyDir: {}` is the type
- mount over a non empty dir hides the image files (not deletes). nginx html + empty emptyDir -> 403
- k8s doesn't copy image files into emptyDir (docker named volume does)
- `subPath` -> mount one file instead of the whole dir
- configMap can be a volume too: every key = a file

### sidecar

- native sidecar = init container with `restartPolicy: Always`
- starts before the app, keeps running, restarted if it exits, stopped after the app, doesn't block a job from finishing
- second container in `containers:` is the old way, k8s doesn't treat it as a sidecar
- classic: log shipper. nginx writes access.log into emptyDir, sidecar does `tail -F` of it to its stdout

### how a pod stops

1. pod is `Terminating`, removed from service endpoints
2. preStop hook
3. SIGTERM to PID 1 of every container
4. wait `terminationGracePeriodSeconds` (default 30s)
5. still alive -> SIGKILL

- PID 1 ignores signals it has no handler for. `sleep 3600` as PID 1 -> delete takes 30s
- `trap '...' TERM` - handler, runs when SIGTERM comes
- `while true; do sleep 1; done` so the trap fires in <=1s, sh waits for the running sleep first
- `time kubectl delete pod <name>` - how long it takes to stop

### Gotchas (fixme)

- typo in the service name in `until nslookup` -> pod is `Init:0/1` forever, logs just say waiting. read the name in the command
- `tail -F /logs/acces.log` instead of `access.log` -> `-F` waits for the file forever, pod `2/2 Running`, no logs. `kubectl logs shipper -c log-shipper` shows `can't open`. compare files with `diff`, not with eyes
- `sh -c "sh /app/server.sh; echo server stopped"` -> PID 1 is the wrapper sh, not the script with the trap. SIGTERM goes to the wrapper, it ignores it and doesn't pass it to the child -> 30s and SIGKILL
- `; echo ...` after the script -> busybox can't exec it, the wrapper stays
- fix: `command: ["sh", "/app/server.sh"]` or `exec sh /app/server.sh` -> the script is PID 1. same as shell form vs exec form in a dockerfile

## 14 october

k8s: day 14. volumes, pv, pvc, storageclass

example

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: site
spec:
  storageClassName: standard           # optional, no field -> default class
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
# deployment, pod template
    spec:
      containers:
        - name: nginx
          image: nginx:1.30-alpine
          volumeMounts:
            - mountPath: /usr/share/nginx/html
              name: site
      volumes:
        - name: site
          persistentVolumeClaim:
            claimName: site
```

### pv, pvc, sc

- pvc = request ("i need 1Gi rwo"), pv = record about one real volume, sc = recipe that creates a new pv for every pvc
- real bytes in kind = a folder on the node: `/var/local-path-provisioner/pvc-..._default_<name>`
- `WaitForFirstConsumer` -> pvc is `Pending` until a pod uses it, then the pv is created on the node of that pod
- `kubectl describe pv` -> Node Affinity + Path = where the data really is. about data ask the pv, not the pod
- delete the pod -> data stays, the new pod goes to the same node (pv nodeAffinity)
- RWO = one node, not one pod. RWX needs nfs/cephfs/efs, local-path can't
- `storageClassName` in pvc: no field -> default class, `""` -> no class, only a manual pv. pvc spec can't be changed -> delete and create again
- deployment + rwo pvc: ok for 1 replica. all replicas share one disk, rolling update can hang on another node -> `strategy: Recreate`

### reclaim policy

- what happens to the pv when the pvc is deleted
- `Delete` (default for dynamic) -> pv and the folder are gone, data too
- `Retain` -> pv stays `Released` with the data, a new pvc doesn't take it, admin cleans up by hand (delete pv + rm the folder on the node)
- sc can't be edited -> my own sc `keep`: copy of `standard` with `reclaimPolicy: Retain`, without the default annotation
- existing pv: `kubectl patch pv <pv> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'`

### commands

- `kubectl exec notebook -- sh -c 'echo hi > /notes/todo.txt'` - `>` inside the quotes, without `sh -c` the redirect runs on my laptop
- `kubectl exec deploy/site -- ...` - exec into a deployment pod without the hash in the name
- `wget -O file url` / `wget -qO- url` - wget saves into a file itself, `wget url > file` gives an empty file
- `docker exec lab-worker2 ls /var/local-path-provisioner` - look at the volume on the kind node

## 18 october

nginx day. btw i hate nets

exapmle of nginx deafult.conf:

```nginx
server {
    listen 80;                    

    location /api/ {
        proxy_pass http://api:8080/;
                
    }

    location /api/admin/ {
        return 403;
                
    }
}
```

### proxy_pass and the slash

- nothing after the port -> nginx sends the path as is
- something after the port (even just `/`) -> nginx cuts the location part from the path and puts that thing instead
- what api got on `curl localhost:8081/api/v1/orders` (`docker logs api`):
  - `location /api/` + `proxy_pass http://api:8080` -> `/api/v1/orders` -> 404, api doesn't know any /api
  - `location /api/` + `proxy_pass http://api:8080/` -> `/v1/orders` -> 200
  - `location /api` + `proxy_pass http://api:8080/` -> `//v1/orders` -> 404. and `/apiv1/orders` works too, location matches a string, not folders
- slash at the end of proxy_pass -> slash at the end of location too

### location

- one `location /api/` catches everything that starts with /api/, i don't write every path of the app
- nginx takes the longest prefix that fits, order in the file doesn't matter -> `/api/admin/` wins over `/api/`
- `/api/admin/users` closes one url, `/api/admin/` closes the whole admin part
- nested location must start with the outer one: `/health` inside `/api/` -> `location "/health" is outside location "/api/"`. nesting isn't needed here at all
- who answered 404: html page with `nginx/1.30.5` = nginx itself, plain text from the app = the request reached the backend

### apply the config

- the folder is mounted -> save the file and the container already sees it
- nginx reads the config only on start and on reload
- `nginx -t` -> check, `nginx -s reload` -> apply without downtime
- no restart: with a broken config the container just won't start
- reload doesn't help when the backend is broken, not nginx

### case 1: 502

- curl -> 502, nginx log: `connect() failed (111: Connection refused) while connecting to upstream, upstream: "http://172.19.0.3:8080/health"`
- = nginx found api and knocked, but nobody listens there
- `docker exec case-api netstat -tln` -> `127.0.0.1:8080`
- `127.0.0.1` = answer only to yourself, `0.0.0.0` = answer to everyone
- in docker and k8s the app must listen on `0.0.0.0`
- fix: `listen=0.0.0.0` in api.cfg + `docker restart case-api` (the app reads its config only on start too)

__on interview:__ service is up, curl on the server gives 200, from outside it doesn't open -> `ss -tln`, `127.0.0.1` -> change to `0.0.0.0`. already `0.0.0.0` -> firewall, port publish (`-p`)

### my mistakes

- nested `location /health` inside `/api/` -> config error, and it wasn't needed
- `location /api/admin/users` instead of `/api/admin/` -> other admin urls still went to api
- `nginx -s reload` on the 502 -> useless, the problem was in api

### commands

- `docker logs api` - which path reached the app
- `docker logs proxy` - nginx errors, read the line to the end
- `docker exec proxy nginx -t` / `docker exec proxy nginx -s reload` - check / apply the config
- `docker exec case-api netstat -tln` - which address the app listens on (no `ss` in the image)
- `docker exec case-api wget -qO- 127.0.0.1:8080/health` - not `localhost`, busybox goes to ipv6 `::1`

## 19 october

k8s: day 15. statefulsets

example

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  clusterIP: None              # headless
  selector:
    app: web
  ports:
    - port: 80
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: web             # the headless service above, sts doesn't create it
  replicas: 3
  # selector + template same as in a deployment
  volumeClaimTemplates:        # one pvc per pod: www-web-0, www-web-1, ...
    - metadata:
        name: www
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 50Mi
```

### headless service

- `clusterIP: None` -> no virtual ip, kube-proxy doesn't touch it, no load balancing
- dns of the service gives ips of all ready pods, the client picks one
- every pod gets its own name: `web-0.web` = `<pod>.<service>`
- no nat -> straight to the pod ip and the port the container listens on
- clusterIP can't be changed -> normal service to headless = delete and create again

### statefulset

- for apps where pods are not the same: db, kafka. every pod has its own data and role
- yaml like a deployment + `serviceName` + `volumeClaimTemplates`
- stable name with a number (`web-0`, not `web-7f9c-x2k`) + dns name. ip is NOT stable
- own pvc from `volumeClaimTemplates`. pod recreated, even on another node -> same pvc
- scale down / delete the sts -> pvcs stay, data too
- starts one by one 0 -> 1 -> 2, each waits for ready of the previous one. down: 2 -> 1 -> 0

### update

- `RollingUpdate` (default): one pod at a time from the biggest number. delete web-2 -> new web-2 -> ready -> web-1
- no surge like in a deployment: two web-2 can't exist, the pvc is one
- not Recreate: recreate kills all pods at once, sts has only one pod down
- `partition: 2` -> only pods with number >= 2 are updated (canary)
- `OnDelete` -> sts updates nothing, i delete a pod by hand and it comes back new
- new pod never ready -> rollout stops, rolling back the yaml may not help, delete the broken pod by hand

__on interview:__ why does a statefulset need a headless service? -> every pod gets a stable dns name instead of one shared ip with balancing

## 21 october

### nginx case 2

i learned that nginx can do like that:

```nginx
server {
    listen 80;
    proxy_read_timeout 10s;

    location /api/ {
        proxy_pass http://case-api:8080/;
    }

    location /api/v1/report {
        proxy_read_timeout 30s;
        proxy_pass http://case-api:8080/v1/report;
    }
}
```

____deafult in proxy_read_timeout is 60s____

### nginx case 3

; - syntax

`` nginx -s reload ``

nginx -t → reload

### k8s: day 16. jobs, cronjobs, daemonsets

| workload | runs | example |
| --- | --- | --- |
| Deployment | N same pods, forever | web, api |
| StatefulSet | N pods with own name and disk, forever | db, kafka |
| DaemonSet | one pod on every node, forever | log agent, kube-proxy |
| Job | pods until the work is done | migration, report |
| CronJob | a job on a schedule | backup, cleanup |

example

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: report
spec:
  backoffLimit: 2              # retries, default 6
  template:
    spec:
      restartPolicy: Never     # only Never or OnFailure
      containers:
        - name: report
          image: busybox:1.38
          command: ["sh", "-c", "echo 'making the report...'; sleep 5; echo 'report done'"]
```

#### job

- exit 0 -> job `Complete`, pod stays `Completed`, logs are still there
- `Never` -> new pod for every retry, `OnFailure` -> container restarts in the same pod
- retries over `backoffLimit` -> `Failed`, `BackoffLimitExceeded`. waits between retries grow: 10s, 20s...
- `completions: 6` + `parallelism: 2` -> 6 pods total, max 2 at once. `completionMode: Indexed` -> `$JOB_COMPLETION_INDEX` 0..5
- `parallel5` (5 at once) -> 9s, one by one would be 5 x (5s + start)
- `activeDeadlineSeconds` -> max time for the whole job, `ttlSecondsAfterFinished` -> job deletes itself
- job template can't be changed -> `kubectl delete job` + apply again
- `kubectl wait --for=condition=Complete job/report --timeout=60s`
- `kubectl logs job/report` - finds the pod itself

#### cronjob

- cronjob -> job -> pod, `jobTemplate` with a `template` inside
- `schedule: "0 3 * * *"` - min hour day month weekday, like linux cron
- no `timeZone` -> time of the control plane, usually utc
- `concurrencyPolicy`: `Allow` (default) / `Forbid` (skip if the old one runs) / `Replace`
- `kubectl create job backup-now --from=cronjob/backup` - run it now with the same settings
- `kubectl patch cronjob backup -p '{"spec":{"suspend":true}}'` - pause without deleting

#### daemonset

- one pod on every node, no `replicas`. new node -> new pod by itself
- kind: 2 pods on 3 nodes -> control-plane has taint `node-role.kubernetes.io/control-plane:NoSchedule`, needs a toleration
- kube-proxy and kindnet are daemonsets -> on all 3 nodes

#### Gotchas (fixme)

- `restartPolicy: Always` in a job -> apply fails, `valid values: "OnFailure", "Never"`. a job must end
- configmap key `data.csv`, script reads `/data/input.csv` -> `can't open`, but job is `Complete` with `imported 0 rows`. key = file name in the volume, read the whole log, not only the status

#### my mistakes

- `command: ["sh", "-c", "sleep", "5"]` -> sh -c takes only the first arg as the script, `5` becomes `$0` -> `sleep` without a number -> `Failed 0/5`. right: `["sh", "-c", "sleep 5"]`

__on interview:__ deployment vs statefulset vs daemonset vs job vs cronjob? -> table above
