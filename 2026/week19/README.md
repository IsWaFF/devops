# week 19

## k8s day 18

debugging networking. a request goes client -> dns -> service -> endpoint -> pod port -> app, any hop can break. go hop by hop, change one thing at a time

### what the error means

| wget says | what's wrong |
|---|---|
| `bad address 'x'` | dns: no such name, service in another namespace, or coredns is dead |
| `Connection refused` | service has no ready endpoints, wrong `targetPort`, app listens on another port |
| `download timed out` | nobody answers: old pod ip, a port the service doesn't have |
| `404` / `502` / `504` | network works, an app (or a proxy) answered with an error |

- `kubectl exec client -- wget -qO- -T 2 http://NAME` - test a service, `-T 2` = give up after 2s
- `kubectl exec client -- nslookup NAME.NS.svc.cluster.local` - test dns, use the full name
- `kubectl get endpointslices -l kubernetes.io/service-name=NAME` - pod ips and port behind a service
- events in `describe` only say *that* it crashes, `logs` say *why*. `--previous` for the crashed run

### service names and ports

- full name: `<service>.<namespace>.svc.cluster.local`, `<service>.<namespace>` works too
- short name `api` works only in the pod's own namespace (`search` in `/etc/resolv.conf`)
- through a service use its `port`, not `containerPort`. `api` has 80 -> `http://api.lab7-api/`, `:9898` -> timeout
- `spec.ports` is a list: `- port: 80`. without `-` -> `cannot unmarshal object ... []v1.ServicePort`

### lab5 - configmap env

- `envFrom` -> every key becomes an env var. var is empty -> `wget: bad address ''`
- `lab5-config` from week18 was still in the cluster, same name, no `BACKEND_URL`. check with `kubectl get cm NAME -o yaml`
- env is read only on start -> after a configmap change `kubectl rollout restart deployment ...`

### lab7 - nginx proxy in another namespace

three bugs in `proxy_pass http://api:9898/v1/;`, fixed: `proxy_pass http://api.lab7-api/;`

- `api` -> nginx resolves names on start, `host not found in upstream "api"` -> crash -> `Connection refused`
- `:9898` -> not a service port -> 504 after `proxy_connect_timeout`
- `/v1/` -> podinfo has no such path -> 404
- nginx log shows the exact upstream url it tried
- wget `-T` shorter than the proxy timeout -> wget gives up first: `download timed out`, 499 in the nginx log
- nginx reads the config only on start -> `kubectl -n lab7-web rollout restart deployment web`

### lab8 - dns is dead

`bad address` for every name, even `kubernetes.default`

1. `kubectl exec client -- cat /etc/resolv.conf` -> `nameserver 10.96.0.10`
2. `kubectl get svc -A | grep 10.96.0.10` -> `kube-dns` in `kube-system`
3. `kubectl -n kube-system get pods -l k8s-app=kube-dns` -> `CrashLoopBackOff`
4. `kubectl -n kube-system logs <coredns pod>` -> `Corefile:13 - Unknown directive 'forwad'`
5. fix the typo in the configmap, restart coredns:

```fish
kubectl -n kube-system edit configmap coredns   # forwad -> forward
kubectl -n kube-system rollout restart deployment coredns
kubectl exec client -- nslookup kubernetes.default.svc.cluster.local   # Address: 10.96.0.1
```

`GOMAXPROCS=12: CPU quota undefined` in the coredns log is not an error, coredns just has no cpu limit
