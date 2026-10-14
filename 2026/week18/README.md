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
