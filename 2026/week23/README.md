# Week 23

## 24.11

interview prep for terraform and terragrunt

- tried terraform with a local nginx container. ran `terraform init` and saved a plan with `terraform plan -out=first.tfplan`. it showed `1 to add`. stopped before `apply`.
- a module reuses the same config with different inputs. the docker provider is the plugin that talks to the docker api.
- state maps resource addresses to real IDs. use a shared backend with locking for team work. if a managed container is deleted by hand and the config stays the same, the next plan proposes recreating it.
- `data` reads an existing object. `resource` describes an object terraform manages.
- terragrunt can run the same module for dev and prod with different `inputs` and separate state. `include` loads shared config from `root.hcl`, and `run --all plan` plans the units under the current directory.

to review: `terraform import`, implicit dependencies from references, `terraform apply first.tfplan`, and passing outputs between terragrunt units with `dependency`.

prepared a short intro in russian and english and went over the shorty release flow. github actions builds and publishes the image, then i update the deployment and check the rollout manually.

# 25.11

today was tecnical interview

and...                  i completed it !!!

happy end.
