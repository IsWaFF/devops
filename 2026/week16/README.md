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
