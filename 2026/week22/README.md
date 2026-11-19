# Week 22

## 17.11

interview prep: docker, git and shorty in english

- `git add` stages the file as it is when the command runs. if i edit it again before `git commit`, the commit still gets the staged version.
- each container has its own writable layer. `docker stop` and `docker start` keep it, `docker rm` removes it.
- `ENTRYPOINT` sets the main command. `CMD` provides default arguments for it, or a default command on its own.

shorty release: github actions builds the image and pushes it to ghcr. then i update the image tag in the deployment, apply the change and check the rollout with `kubectl rollout status`.

## 18.11

interview prep: linux and bash, partly in english

- if a service fails to start, check `systemctl status myapp.service` and `journalctl -u myapp.service`.
- in `free -h`, `available` estimates how much memory apps can use without swapping, including reclaimable cache.
- on a directory, `r` lets you list names, `x` lets you access entries by name, and `w` + `x` let you create or remove entries. `namei -l` shows permissions along the path.
- `$?` is the last exit status, `$$` is the shell pid, `$!` is the last background pid, `"$@"` is all positional args, and `$#` is their count.

## 19.11

- ctrl+c sends `SIGINT` to the foreground process group.
- `cmd 2>&1 | grep error` sends stdout and stderr into the pipe. redirects run left to right: `>out 2>&1` sends both to the file, while `2>&1 >out` only sends stdout to the file.
- slow server: start with `top`, `free -h` and `df -h`. check load average, process states, cpu usage and i/o wait in `top`.
- ansible: a task calls a module with arguments. for nginx on debian, use `ansible.builtin.apt` with `name: nginx` and `state: present`. reviewed inventory, variables, roles and handlers with `notify`.

to review: nginx upstream errors (502 vs 504) and the proxy incident.
