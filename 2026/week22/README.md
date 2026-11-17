# Week 22

## 17.11

interview prep: docker, git and shorty in english

- `git add` stages the file as it is when the command runs. if i edit it again before `git commit`, the commit still gets the staged version.
- each container has its own writable layer. `docker stop` and `docker start` keep it, `docker rm` removes it.
- `ENTRYPOINT` sets the main command. `CMD` provides default arguments for it, or a default command on its own.

shorty release: github actions builds the image and pushes it to ghcr. then i update the image tag in the deployment, apply the change and check the rollout with `kubectl rollout status`.
