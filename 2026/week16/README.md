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

a pod goes into it with `namespace: shop2` in its metadata, see [k8s/shop.yaml](k8s/shop.yaml)

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
