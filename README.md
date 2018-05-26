# tf

> Terraform helper script. Manages file based state. Encapsulates to
simplify and shorten cli commands.

## File based state
s3 backend is the accepted way to go when working with a larger DevOps teams. However,
state files tagged in a repo work fine for smaller shops. This script helps to simplify
and automate some of the terraform CLI calls, when using file based state.

```

## Usage
From `--help` text

```
Script: tf
Usage: tf [options]

  Options:
    -h|--help:  help and usage
    -v| --version: show version info

    --var:  show vars in terraform.tfvars file
    --init: Run formatted terraform init
    --plan: Run formatted terraform plan
    --apply: Run formatted terraform apply
    --dist: put it in script path directory

  Examples:
    tf --vars
    tf --init --ws=prod
    tf --init -s3 --ws=dev
    tf --plan --ws=dev
    tf --apply --ws=dev
```


### Typical Project Structure
This is for use in projects separated by environment and or function, something
like below. Here the terraform.tfvars holds system wide
variable assignments.

- terraform
  terraform.tfvars
  - development
    - services
    - vpc
  - global
    - iam
    - s3
  - management
    - services
    - vpc
  - modules
    - data_sources
    - services
    - vpc
  - production
    - services
    - vpc
  - qa
    - services
    - vpc
  - staging
    - services
    - vpc

```

## [License](LICENSE.md)
