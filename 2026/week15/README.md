# week 15

## 21 september

k8s kind. starting practice + theory.

## 22 september

k8s practice

### kind: the cluster itself

| command | what it does |
|---|---|
| `kind create cluster --name devops` | Make a new cluster. |
| `kind get clusters` | Show all your clusters. |
| `kind delete cluster --name devops` | Delete the cluster and everything in it. |
| `kind load docker-image shorty:0.1 --name devops` | Copy your local image into the cluster. The cluster can't see your Docker images without this. |

### kubectl: see what is running

| command | what it does |
|---|---|
| `kubectl get nodes` | Show the machines in the cluster. |
| `kubectl get pods` | Show pods in the current namespace. |
| `kubectl get pods -A` | Show pods in all namespaces. |
| `kubectl get pods -o wide` | Show pods with more info: IP and node. |
| `kubectl get all -n shorty` | Show pods, services, deployments and replica sets in one namespace. |
| `kubectl get pods -w` | Watch pods live. Press Ctrl+C to stop. |

### kubectl: find out why something is broken

| command | what it does |
|---|---|
| `kubectl describe pod <name>` | Full info about a pod. Read **Events** at the bottom first. |
| `kubectl logs <pod>` | Show what the app printed. |
| `kubectl logs <pod> --previous` | Logs of the container that crashed before. Use it for CrashLoopBackOff. |
| `kubectl logs -f deploy podname` | Follow logs live from a deployment. |
| `kubectl get events --sort-by=.lastTimestamp` | Recent events in the namespace, newest last. |
| `kubectl exec -it <pod> -- sh` | Open a shell inside a pod. |

### kubectl: create and change things

| command | what it does |
|---|---|
| `kubectl apply -f file.yaml` | Create or update things from a file. |
| `kubectl apply -f k8s/` | Apply all files in a folder, in alphabet order. |
| `kubectl apply --dry-run=server -f k8s/` | Check the files on the server. Creates nothing. |
| `kubectl diff -f k8s/` | Show what will change before you apply. |
| `kubectl delete -f file.yaml` | Delete what the file created. |
| `kubectl delete pod <name>` | Delete one pod. The Deployment makes a new one. |

### kubectl: deployments

| command | what it does |
|---|---|
| `kubectl scale deploy podname --replicas=3` | Change how many copies run. |
| `kubectl rollout status deploy podname` | Wait and show if the update finished. |
| `kubectl rollout restart deploy podname` | Restart all pods one by one, for example after you change a ConfigMap. |
| `kubectl rollout history deploy podname` | Show old versions. |
| `kubectl rollout undo deploy podname` | Go back to the previous version. |

### kubectl: get to your app from the laptop

| command | what it does |
|---|---|
| `kubectl port-forward svc podname 8080:80` | Open localhost:8080 and send it to the service. Works while the terminal is open. |
| `kubectl port-forward pod/<name> 8000` | Same, but to one pod. |

### kubectl: namespace and context

| command | what it does |
|---|---|
| `kubectl get ns` | Show all namespaces. |
| `kubectl config current-context` | Show which cluster kubectl talks to now. |
| `kubectl config set-context --current --namespace=shorty` | Make shorty the default namespace, so you don't need -n every time. |

### kubectl: help without Google

| command | what it does |
|---|---|
| `kubectl explain deployment.spec` | Show what fields go here and what they mean. |
| `kubectl create deployment podname --image=x --dry-run=client -o yaml` | Print a starter YAML. Creates nothing. |
| `kubectl get deploy podname -o yaml` | Show the full YAML of something that already runs. |
| `kubectl <command> --help` | Help and examples for any command. |

**Short names** save typing: `po` = pods, `svc` = services, `deploy` = deployments, `cm` = configmaps, `ns` = namespaces, `pvc` = persistentvolumeclaims, `sts` = statefulsets.

When something breaks, go in this order: `get pods` → `describe pod` (Events) → `logs` / `logs --previous`.

## 23 september

completed ["Cairo": Time for a Timer](https://sadservers.com/scenario/cairo) on a second try, 11:52, 0 clues

**key fixes and commands:**

- cat /opt/scripts/health.sh
- cat /var/log/health.log
- sudo ss -tlnp
- curl -s --max-time 2 http://localhost
- sudo iptables -L -n -v --line-numbers

problem was iptables rule in OUTPUT that drops everything to 127.0.0.1:80, so curl just hangs. and health.timer was not enabled

__answer:__

- sudo iptables -D OUTPUT 1
- sudo systemctl daemon-reload
- sudo systemctl enable --now health.timer

checker didn't need it, but on a real server also:

- sudo ip6tables -L -n -v (same rule for ipv6)
- sudo netfilter-persistent save (or rule comes back after reboot)
- AccuracySec=1s in timer (default lets it be late up to 1 min)

curl hangs = packets dropped somewhere. fast 404/500 = server answered

### systemd timer vs cron

main difference: timer is a systemd unit, so you need 2 files, .service (what to run) and .timer (when to run). you get systemctl status and journalctl -u. cron is one line

/etc/systemd/system/backup.service

```ini
[Unit]
Description=Backup job

[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup.sh
```

/etc/systemd/system/backup.timer

```ini
[Unit]
Description=Run backup daily

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

enable:

- sudo systemctl daemon-reload
- sudo systemctl enable --now backup.timer (enable .timer, not .service)
- systemctl list-timers

same in cron:

- 0 3 * * * /usr/local/bin/backup.sh

### iptables

rules are in chains:

- INPUT - packets coming to the server
- OUTPUT - packets server sends, also to itself (curl localhost)
- FORWARD - packets going through (docker)

rules go top to bottom, first match wins, if nothing matched then chain policy. pkts column = how many packets hit the rule, if it grows when you curl thats your rule. DOCKER-* chains are docker stuff, skip them

- ACCEPT - let through
- DROP - throw away silently, client hangs
- REJECT - refuse, client gets error fast

commands:

- sudo iptables -L -n -v --line-numbers - list rules with counters and numbers
- sudo iptables -S - rules as commands
- sudo iptables -t nat -L -n -v - nat table
- sudo iptables -D OUTPUT 1 - delete rule 1 in OUTPUT
- sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT - add rule to the end
- sudo iptables -I INPUT 1 ... - add rule to the top
- sudo ip6tables -L -n -v - same for ipv6
- sudo netfilter-persistent save - save rules, rules file is /etc/iptables/rules.v4

## 24 september

started my vibecoded kuber challange. **DAY 1**

 __new for me:__

- kubectl run podname --image=nginx:1.30-alpine - run pod
- kubectl describe pod podname - see pod card, actions
- kubectl logs podname - see logs
- kubectl exec -it podname -- sh  -  to enter into the pod
- kubectl port-forward pod/podname 8080:80 - to forward port to local machine
- kubectl delete pod podname - __**not foget!!**__

## 25 september

day 2 of challange. todays topic was YAML. 

**main commands:**
- kubectl apply -f k8s/manifest.yaml
- kubectl api-resources - to get ApiVersion filed
- kubectl diff -f
- kubectl run gen --image=image --dry-run=client -o yaml - to get tempplate of pod yaml
- kubectl explain <>.<>.<>

completed ["Bergen": Port already in use](https://sadservers.com/scenario/bergen), ~30 min, 0 clues. check.sh said OK, but i closed the scenario tab and couldn't press Check on the site. next time keep that tab open until check

**key fixes and commands:**

- /home/admin/standalone - listen tcp4 0.0.0.0:8000: bind: address already in use
- sudo ss -ltnp 'sport = :8000' - who listens on the port
- sudo lsof -i :8000 - same
- curl localhost:8000 - "hello SadServers", same thing port 80 must show
- sudo systemctl status django.service
- grep -rn proxy_pass /etc/nginx/

problem was django dev server (django.service) sitting on 8000, the same port standalone wants. and nginx on 80 is a reverse proxy to django on 8000, so you can't just kill django or web on 80 dies

__answer:__

- sudo nano /etc/systemd/system/django.service - runserver 0.0.0.0:8000 -> 0.0.0.0:8001
- sudo systemctl daemon-reload
- sudo systemctl restart django
- sudo nano +7 /etc/nginx/sites-available/bergen - proxy_pass http://127.0.0.1:8001;
- sudo nginx -t && sudo systemctl reload nginx
- curl localhost - hello SadServers
- ./standalone - OK

my mistakes:

- checked iptables, but error said port is used, not blocked. read the error first
- moved django to port 80 -> it crashed (nginx is already there) and nginx gave 502
- disable/kill/enable dance, daemon-reload + restart is enough

502 Bad Gateway = nginx is alive, but the app behind it doesn't answer

### nginx: sites-available vs sites-enabled

- sites-available/ - all site configs, also turned off ones
- sites-enabled/ - symlinks to the ones that work, nginx reads only these
- ls -l /etc/nginx/sites-enabled/ - see what is on
- edit file in sites-available, symlink sees the changes
- grep -r doesn't follow symlinks, grep -R does

reverse proxy (proxy_pass) is not redirect. redirect = 301/302, browser goes to new url itself. proxy = nginx goes to the app and gives answer back to client
