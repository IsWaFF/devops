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
