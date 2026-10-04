# Week 16

## 28 september

k8s ch day 4. today's topic was labels, selectors and namespaces, and how to use them in kubectl

### labels

labels are key=value tags in `metadata`. kubectl, Deployments and Services find pods by them

```yaml
metadata:
  name: web-dev
  labels:
    app: web
    env: dev
```

- `kubectl get pods --show-labels` - show all labels of every pod
- `kubectl get pods -L app,env` - show chosen labels as columns
- `kubectl label pod web-dev tier=backend --overwrite` - change a label. without `--overwrite` kubectl refuses to change an existing one

### selectors (`-l`)

- `kubectl get pods -l app=web,env!=prod` - comma = AND. `!=` also matches pods that don't have the key
- `kubectl get pods -l 'app in (web,db)'` - app is web or db. **quotes are required in fish**, without them `( )` is command substitution

### namespaces

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: shop2
```

a pod goes into it with `namespace: shop2` in its metadata, see [k8s/day5/shop.yaml](k8s/day5/shop.yaml)

- `kubectl get pods -n team-a` - pods in one namespace

**important!!** after `kubectl config set-context --current -n team-a` every command without `-n` goes to team-a. when done, always go back:

- `kubectl config set-context --current -n default`

## 29 september

kubernetes day 5!

i'm glad to say that i'm finally starting to understand kuber manifests, more than ever.

today's topic was deployments

### deployment

example of a deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: podinfo
  labels:
    app: podinfo
spec:
  replicas: 3                  # how many Pods
  selector:                    # which Pods belong to this Deployment
    matchLabels:
      app: podinfo
  template:                    # the Pod template (a Pod without apiVersion/kind)
    metadata:
      labels:
        app: podinfo           # must match the selector!
    spec:
      containers:
        - name: podinfo
          image: ghcr.io/stefanprodan/podinfo:6.14.1
          ports:
            - containerPort: 9898
```

- `kubectl scale deployment podinfo --replicas=5`

if we change the label of a deployment's pod to another one, it escapes the deployment

### sadservers

completed ["Kortenberg": Can't touch this!](https://sadservers.com/scenario/kortenberg), ~40 min, 0 clues, 2 hints from claude

**key fixes and commands:**

- mkdir swag && ls -la - new dir is d---------, so nobody can do anything with it
- umask - 0777
- umask -S - u=,g=,o= (same thing, but readable)
- bash -l -c umask - what a new login shell gets (this is how the checker logs in), not my current shell
- cat ~/agent/check.sh
- ls -la ~ - .profile date is dec 1 (same as agent/, when the scenario was made), .bashrc is jul 30 (package default)

problem was umask 0777 in /etc/profile, it runs on every login shell. ~/.profile didn't fix anything

**answer:**

- sudo vim /etc/profile - umask 0777 -> umask 022
- umask 022 - fix the current shell too
- bash -l -c umask - 0022

my mistakes:

- put umask in .bashrc -> check said no. debian .bashrc starts with `case $- in *i*) ;; *) return;; esac`, so in a non-interactive shell (the checker) it quits before my line
- changed umask before finding where 0777 comes from. find the source first, then fix it there

### umask

umask takes permissions away from the default ones: 666 for files, 777 for dirs

- 022 -> files 644, dirs 755 (normal)
- 0777 -> files ---------, dirs d---------

login shell reads: /etc/profile -> first of ~/.bash_profile, ~/.bash_login, ~/.profile -> .profile runs .bashrc

## 30 september

k8s day 6, rolling updates

### rollout

- `kubectl rollout`
- `kubectl rollout status deployment/podinfo`

| Setting | Meaning | Default |
| --- | --- | --- |
| `maxSurge` | How many Pods **more** than `replicas` may exist during the update | 25% |
| `maxUnavailable` | How many Pods **less** than `replicas` may be ready during the update | 25% |

| maxSurge | maxUnavailable | Behaviour |
| --- | --- | --- |
| 1 | 0 | Safest: first start a new Pod, wait until it's ready, then stop an old one. Needs extra resources. |
| 0 | 1 | No extra Pods (good when the cluster is full), but one Pod less during the update. |
| 100% | 0 | Start all new Pods at once, then remove the old ones (fast, needs double resources). |

- `kubectl rollout history deployment/podinfo`
- `kubectl rollout undo deployment/podinfo`

```yaml
spec:
  strategy:
    type: Recreate
```

### sadservers

completed ["Fukuoka": Forbidden Association](https://sadservers.com/scenario/fukuoka)

**key fixes and commands:**

- `curl -v http://localhost` - 404 from nginx, so the port is fine
- `sudo tail /var/log/nginx/error.log` - `stat() "/var/www/html/" failed (13: Permission denied)`
- `sudo nginx -T | grep -E '^\s*(root|index)'` - root is /var/www/html
- `ps aux | grep nginx` - workers run as www-data
- `sudo namei -l /var/www/html/index.html` - permissions of every dir on the path, follows the symlink
- `sudo -u www-data cat /var/www/html/index.html` - check as www-data, not as root

problem: www-data had no `x` on /var/www (-> 404) and no `r` on /opt/site-content/real_index.html, the symlink target (-> 403)

**answer:**

- `sudo chmod o+x /var/www`
- `sudo chgrp www-data /opt/site-content/real_index.html` (or `chmod o+r`)

my mistakes:

- `sudo nginx` while nginx was already running, chmod on index.nginx-debian.html (not in the log), reload after every chmod (not needed)
- `chmod -R 777` instead of 2 bits

### permissions

- dir: `r` = list names, `x` = go through. file: `r` = read
- to read a file you need `x` on every dir in the path + `r` on the file
- symlink permissions don't matter, the target's do
- `chmod o+rx` - add single bits instead of numbers

## 1 october

### k8s Day 7 - Services and DNS

Service - stable ip for pods !

```yaml
apiVersion: v1
kind: Service
metadata:
  name: podinfo
spec:
  selector:            # send traffic to Pods with these labels
    app: podinfo
  ports:
    - name: http
      port: 80         # the port of the Service
      targetPort: 9898 # the port of the container in the Pod
```

- `port` - what clients call, `targetPort` - where the app in the pod listens. no targetPort -> same as port
- `targetPort: http` - port by name, the name is set in the pod's `ports:` (see [k8s/podinfo-8080.yaml](k8s/podinfo-8080.yaml))
- `kubectl get endpointslices -l kubernetes.io/service-name=podinfo` - pod IPs behind the service. empty -> selector doesn't match pod labels
- `kubectl exec client -- wget -qO- http://podinfo` - test from a pod
- ClusterIP doesn't answer ping, kube-proxy only forwards TCP/UDP to the service ports

dns: `podinfo` - same namespace, `backend.backend` - other namespace, `backend.backend.svc.cluster.local` - full name

## 2 october

### sadservers

completed ["Bilbao": Basic Kubernetes Problems](https://sadservers.com/scenario/bilbao)

main thing i learned: a pod can have a selector for a node (`nodeSelector`)

**key fixes and commands:**

- `cat manifest.yml` - `nodeSelector: disk: ssd`, requests `memory: 2000Mi`
- `k describe pod <pod>` - Events: `0/1 nodes are available: 1 Insufficient memory`
- `k describe node node1` - `Allocatable` and `Allocated resources`, how much is left for requests

problem: no node with label `disk=ssd` + the 2000Mi memory request didn't fit on the node

**answer:**

- `k label node node1 disk=ssd` (or remove nodeSelector)
- requests memory 2000Mi -> 200Mi in manifest.yml, `k apply -f manifest.yml`

my mistakes:

- cpu request 100m -> 50m, Events said nothing about cpu
- `k delete -f` + `apply` twice. `apply` alone updates the deployment, after the label the scheduler retries the pending pod by itself

### resources

- the scheduler looks at requests, not at real usage (top/free). free = Allocatable - requests in Allocated resources
- request - reserved for the pod, limit - max (memory -> OOMKilled, cpu -> throttled)
- cpu: `1` = `1000m`, `100m` = 0.1 core. memory: `Ki/Mi/Gi` (x1024), `memory: 200m` = 0.2 bytes
- kind: every node sees the whole laptop (12 cpu)

## k8s day 8

### k8s Day 8 - Reaching Your App

all types balance between pods (kube-proxy), not only LoadBalancer. each next type = previous one + one more thing:

- ClusterIP - one virtual ip `10.96.x.x`, only from inside the cluster
- NodePort - ClusterIP + port 30000-32767 on every node, from outside: `node_ip:port`
- LoadBalancer - NodePort + external ip from the cloud. kind has no cloud -> `EXTERNAL-IP <pending>` forever
- headless (`clusterIP: None`) - no virtual ip at all, dns returns pod ips

```yaml
spec:
  type: NodePort
  ports:
    - port: 80          # ClusterIP port, inside the cluster
      targetPort: 9898  # container port
      nodePort: 30080   # port on every node. no nodePort -> random (my podinfo-random got 31929)
```

**port-forward:**

- `kubectl port-forward service/podinfo 8080:80` - tunnel only for me, picks one pod at start, no balancing

**nodeport and localhost:**

- nodeport listens on the node ip, not on my laptop
- kind: node = docker container, `kubectl get nodes -o wide` -> 172.18.0.x. so `curl 172.18.0.8:31929` works, `curl localhost:31929` - failed to connect
- docker desktop forwards nodeports to localhost, that's why `localhost:30080` works for them
- any node works, even without a pod on it - kube-proxy opens the port on all nodes

**keep-alive:**

- kube-proxy balances tcp connections, not requests (L4)
- separate `curl` -> different pods. browser F5 -> same pod, it keeps one connection open
- per-request balancing = L7 (Ingress/Gateway). long connections (gRPC) stick to one pod

**headless:**

- `nslookup podinfo.default.svc.cluster.local` -> one ip `10.96.212.85`, same after scaling
- `nslookup podinfo-headless.default.svc.cluster.local` -> pod ips, 3 replicas = 3 ips, scale to 5 = 5 ips
- needed when "any pod" is not ok: StatefulSet/databases (`postgres-0.<svc>`), client balances itself (gRPC), pods find each other (etcd, kafka)
- nslookup takes a name, not url: `http://podinfo` -> NXDOMAIN

## 4 october

today is a chill day, the only thing i learned is for CI

### set -x

`set -x` - logging in scripts

BAD example:

```bash
KEY="super-secret"
set -x
echo "$KEY" > key.txt
```

log output:

```
+ echo super-secret
```

the key is leaking!!

best practice:

```bash
KEY="super-secret"
set -x
echo "start deploy"
set +x
echo "$KEY" > key.txt
set -x
echo "deploy done"
```

`set +x` - logging off
