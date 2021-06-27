# kubernetized-bookstack
> General description:
kubernetized-bookstack create the infrastructure onto scaleway and k8s needed by bookstack then deploy booktack.

### Table of contents
* [Prerequisites](#prerequisites)
* [Setup](#setup-terraform)
* [How to use](#how-to-use-terraform)
* [How to Commit](#how-to-commit)

### Prerequisites
| Technologies | Versions |
| ------ | ------ |
| Terraform | 1.14+ |
| scw cli | 2.3.0 |

### Setup
To choose the workspace
```bash
export TF_WORKSPACE=production
# or
export TF_WORKSPACE=development
```

Choose on which scaleway project you want to deploy the stack with
```bash
scw config profile activate {dev_or_prod_profile_name}
```

then
```bash
export TF_CLI_ARGS_apply="-parallelism=3 -auto-approve"
export TF_IN_AUTOMATION=1
export SCW_ACCESS_KEY=$(scw config get access-key)
export SCW_SECRET_KEY=$(scw config get secret-key)
```

then
```bash
export AWS_ACCESS_KEY_ID=$(scw config get access-key)
export AWS_SECRET_ACCESS_KEY=$(scw config get secret-key)
```

For the bookstack image S3 backend
```bash
export TF_VAR_scw_bucket_access_key=
export TF_VAR_scw_bucket_secret_key=
```

### How to use terraform
```bash
terraform init terraform/
terraform plan -out=tfplan --var-file terraform/terraform.tfvars terraform/
terraform apply tfplan
```

### How to commit
Here is a guide to make clean commit in this project.
```sh
$ git commit -m "[STATUS] Here is the message"
```
**Status**
* ADD : When you add a new file or a new functionality
* UPDATE : When you modify a functionality
* DONE : When you finish a task/function
* WIP : When your work still in progress
* BUG : In case you create a Bug
* FIXED : When you fixed a bug

**Examples**
```
$ git commit -m "[ADD] newFunction()"
$ git commit -m "[DONE] Lambda x"
$ git commit -m "[WIP] missing return statement newFunction()"
$ git commit -m "[BUG] callLambda() don't work"
$ git commit -m "[FIXED] callLambda() don't work: API gateway did not allowed usage of GET method"
```
You can combine status
```
git commit -m "[WIP/BUG] still working on callLambda() bug"
```
