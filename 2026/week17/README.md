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
