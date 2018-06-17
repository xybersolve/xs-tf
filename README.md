# tf

> Terraform helper script. Manages file based state. Encapsulates to
simplify and shorten common cli commands.

## Usage (from --help)

```sh

$tf --help

  Script: ${PROGNAME}
  Purpose: Helper script for Terraform
  Usage: ${PROGNAME} [options]

  Options:
    --help:  help and usage

    --val: Validate
    --init, -i: Run formatted terraform init
    --plan, -p: Run formatted terraform plan
    --apply, -a: Run formatted terraform apply
    --run, -r: Run all: validate -> init -> plan -> apply
    --des, -d: Destroy infrastructure in plan

    --dist: Copy script files into script bin directory
    --var:  show vars in terraform.tfvars file
    --copy-env, -c: Copy 'env.tf' (shared project variables) to current directory
      * env.tf holds variable definitions shared globally across projects

  Examples:
    Initialize:
      ${PROGNAME} -i
      ${PROGNAME} --init
    Plan:
      ${PROGNAME} -p
      ${PROGNAME} --plan
    Apply:
      ${PROGNAME} -a
      ${PROGNAME} --apply
    Run:
      ${PROGNAME} -r
      ${PROGNAME} --run
    Run all:
      ${PROGNAME} -i -p -a
      ${PROGNAME} --init --plan --apply
    Support:
      ${PROGNAME} --copy-env
      ${PROGNAME} --vars
      ${PROGNAME} --dist

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
