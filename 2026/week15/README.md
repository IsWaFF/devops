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
| `kubectl logs -f deploy/web` | Follow logs live from a deployment. |
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
| `kubectl scale deploy/web --replicas=3` | Change how many copies run. |
| `kubectl rollout status deploy/web` | Wait and show if the update finished. |
| `kubectl rollout restart deploy/web` | Restart all pods one by one, for example after you change a ConfigMap. |
| `kubectl rollout history deploy/web` | Show old versions. |
| `kubectl rollout undo deploy/web` | Go back to the previous version. |

### kubectl: get to your app from the laptop

| command | what it does |
|---|---|
| `kubectl port-forward svc/web 8080:80` | Open localhost:8080 and send it to the service. Works while the terminal is open. |
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
| `kubectl create deployment web --image=x --dry-run=client -o yaml` | Print a starter YAML. Creates nothing. |
| `kubectl get deploy web -o yaml` | Show the full YAML of something that already runs. |
| `kubectl <command> --help` | Help and examples for any command. |

**Short names** save typing: `po` = pods, `svc` = services, `deploy` = deployments, `cm` = configmaps, `ns` = namespaces, `pvc` = persistentvolumeclaims, `sts` = statefulsets.

When something breaks, go in this order: `get pods` → `describe pod` (Events) → `logs` / `logs --previous`.
