#!/usr/bin/env bash
# ================================================================
# -*- mode: bash -*-
# vi: set ft=sh
# ****************************************************************
#
# DESCRIPTION
#    Helper script for Terraform
#
# SYNTAX & EXAMPLES
#    See 'SYNTAX' (below)
#
# ----------------------------------------------------------------
# IMPLEMENTATION
#    version         script 0.0.4
#    author          Greg Milligan
#    copyright       Copyright (c) 2017 http://www.xybersolve.com
#    license         GNU General Public License
#
# ================================================================
#  DEBUG OPTION
#    set -n  # Uncomment to check your syntax, without execution.
#    set -x  # Uncomment to debug this shell script
#
# ---------------------------------------------------------------
#
# TODO:
# ****************************************************************


# ---------------------------------------
# CONFIGFURATION
# ---------------------------------------
# strict environment
set -o errexit  # exit on command error status
set -o nounset  # no unreadonlyd variables
set -o pipefail # failr on pipe failures
trap 'echo "Aborting due to errexit on line $LINENO. Exit code: ${?}" >&2' ERR

# ---------------------------------------
# GLOBAL VARIABLES
# ---------------------------------------
# booleans
declare -ir TRUE=1
declare -ir FALSE=0
# script info

declare -r PROGNAME="$(basename ${0})"
declare -r VERSION=0.0.1
declare -r SUBJECT=""
declare -r KEYS=""
declare -ri MIN_ARG_COUNT=1
declare -r SYNTAX=$(cat <<EOF

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

EOF
)

# files & directories
declare -r SCRIPT_FILE="${0}"
declare -r SCRIPT_DIR="$( dirname ${0} )"

# actions
declare -i SET_WORKSPACE=${FALSE}
declare VALIDATE=${FALSE}
declare -i INIT=${FALSE}
declare -i PLAN=${FALSE}
declare -i APPLY=${FALSE}
declare -i RUN=${FALSE}
declare -i DESTROY=${FALSE}
declare -i SHOW_VARS=${FALSE}
declare -i GO_HOME=${FALSE}
declare -i DISTRIBUTE=${FALSE}
declare -i COPY_ENV=${FALSE}

# flags
declare -i S3_BACKEND=${FALSE}

# script globals
declare WORKSPACE=''
declare -r WORK_DIR=$(pwd)
declare -r CONFIG_FILE="${SCRIPT_DIR}/tf.config.sh"
#declare -r VAR_FILE=$(realpath "${WORK_DIR}/../../terraform.tfvars")
declare VAR_FILE=''
# default to terraform expected plan file
declare PLAN_FILE=./terraform.tfplan
# ---------------------------------------
# COMMON FUNCTIONS
# ---------------------------------------
usage() {
  echo "${SYNTAX}"
}

error() {
  printf "\n%s\n" "Error: ${1}"
}

die() {
  error "${1}"
  usage
  printf "\n\n"
  exit "${2:-1}"
}

show_version() {
  printf "\n\n%s  %s\n\n\n" "${PROGNAME}" "${VERSION}"
  exit 0
}

show_help() {
  printf "\n\n"
  usage
  printf "\n\n"
  exit 0
}

# ---------------------------------------
# MAIN ROUTINES
# ---------------------------------------
source "${CONFIG_FILE}" \
  || die "Unable to load Config File: ${CONFIG_FILE}"

# common variable file at base of all environments
VAR_FILE="${BASE_DIR}/terraform.tfvars"
#
# Primary Terraform execution routines
#
__show_vars() {
  # debug
  echo "Showing var file: ${VAR_FILE}"
  cat "${VAR_FILE}"
}

__validate() {
  terraform validate \
    --var-file "${VAR_FILE}"
}

__init() {
  #__check_workspace
  # echo terraform init --var-file="${VAR_FILE}"
  # return 0
  if (( S3_BACKEND  && SET_WORK_SPACE )); then
    terraform init \
       --var-file="${VAR_FILE}" \
       --backend-config="dynamodb_table=xs-tfstatelock" \
       --backend-config="bucket=xs-tf-network" \
       --backend-config="profile=deployment"
  else
    terraform init \
      --var-file="${VAR_FILE}"
  fi
}

__plan() {
  #__check_workspace
  #echo "terraform plan --var-file=${VAR_FILE} -out ${PLAN_FILE}"
  #return 0
  terraform plan \
    --var-file="${VAR_FILE}" \
    -out "${PLAN_FILE}"

  # passing in access keys and region
  # terraform plan -out="${PLAN_FILE}" \
  #   -var "access_key=${AWS_ACCESS_KEY_ID}" \
  #   -var "secret_key=${AWS_SECRET_ACCESS_KEY}" \
  #   -var "region=${AWS_DEFAULT_REGION}"

}

__apply() {
  #__check_workspace
  #echo terraform apply "${PLAN_FILE}"
  #return 0
  terraform apply "${PLAN_FILE}"
}

__run() {
  __validate && \
  __init && \
  __plan && \
  __apply
}

__destroy() {
  terraform destroy \
    --var-file="${VAR_FILE}"
}

#
# Support Routines
#
__copy_env() {
  local -r file='env.tf'
  cp "${BASE_DIR}/${file}" "${PWD}/${file}"
}

__set_workspace() {
  terraform workspace select "${WORKSPACE}" ||
    die "Workspace was not found: ${WORKSPACE}" 4
  # s3 doesn't use the PLAN_FILE
  (( S3_BACKEND )) \
    || PLAN_FILE="terraform-${WORKSPACE}.tfplan"
}

__get_workspace() {
  # set the WORKSPACE variable with current
  WORKSPACE="$(terraform workspace show)"
  #echo "Workspace: ${WORKSPACE}"
}

__check_workspace() {
  # if workspace wasn't set --ws=<workspace>
  (( SET_WORKSPACE )) || die "--ws=<workspace> is a required argument" 3
}

__check_virtualenv() {
  local cur_dir="$(pwd)"
  if ! (( DISTRIBUTE )); then
    if [[ "${cur_dir}" != "${VIRTUALENV_DIR}" ]]; then
        printf "\n🛠  Must set virtualenv first\n";
        if [[ -d "${VIRTUALENV_DIR}" ]]; then
          echo -e "cd ${VIRTUALENV_DIR}\n" | pbcopy
          printf "Switch to base directory:%s\n" "${VIRTUALENV_DIR}"
          printf "Press: Ctrl V\n"
          printf "then, run: '. pyon'\n\n"
        else
          printf "  Couldn't find virtualenv directory: %s\n" "${VIRTUALENV_DIR}"
        fi
        exit 1;
    fi
  fi
}

__check_project_dir() {
  if ! (( DISTRIBUTE )); then
    [[ -f "${BASE_DIR}/terraform.tfvars" ]] \
      || die "Something is wrong, couldn't find project terraform.tfvars" 3
  fi
}

__go_home() {
  exec cd "${PROJECT_DIR}"
}

#
# Distribution routines
#
__distribute() {
  local file=''
  local -r dest=~/bin
  local -ra files=(
    "${SCRIPT_FILE}"
    "${CONFIG_FILE}"
  )
  printf "\n"
  for file in "${files[@]}"; do
    cp "${file}" "${dest}" \
      && printf "👍🏻  Copied: %s to %s\n" "${file}" "${dest}"
  done
  printf "\n"

  #cp "${SCRIPT_DIR}/.tf" ~/bin \
  #  && printf "👍🏻  Copied script to \bin script directory"

}
#
#  Action switch & dispatch routines
#
__get_opts() {
  while (( $# > 0 )); do
    local arg="${1}"; shift;
    case ${arg} in
      --help)    show_help                 ;;
      # primary init, plan, apply, run & destroy actions
      --val*|-v)        VALIDATE=${TRUE}  ;;
      --init|-i)        INIT=${TRUE}      ;;
      --plan|-p)        PLAN=${TRUE}      ;;
      --apply|-a)       APPLY=${TRUE}     ;;
      --run|-r)         RUN=${TRUE}       ;;
      --des*|-d)        DESTROY=${TRUE}   ;;

      --copy-env)    COPY_ENV=${TRUE}     ;;
      --vars)        SHOW_VARS=${TRUE}    ;;

      # -- boolean flags
      --s3)          S3_BACKEND=${TRUE}   ;;
      --home)        GO_HOME=${TRUE}      ;;

      # workspace - not currently used
      --ws*)
        SET_WORKSPACE=${TRUE}
        [[ ${arg} =~ '=' ]] && WORKSPACE="${arg#*=}"
        ;;
      --get-workspace) __get_workspace    ;;

      # distribution (local)
      --dist*)      DISTRIBUTE=${TRUE}     ;;

      *) die "Unknown option: ${arg}" ;;
   esac
  done
  return 0
}

__dispatch() {
  # always must be in virtualenv
  # __check_virtualenv
  (( SET_WORKSPACE )) && __set_workspace
  (( SHOW_VARS )) && __show_vars
  (( VALIDATE )) && __validate
  (( INIT )) && __init
  (( PLAN )) && __plan
  (( APPLY )) && __apply
  (( RUN )) && __run
  (( DESTROY )) && __destroy
  (( GO_HOME )) && __go_home
  (( COPY_ENV )) && __copy_env
  (( DISTRIBUTE )) && __distribute
  return 0
}

main() {
  (( ${#} < MIN_ARG_COUNT )) && die "Expects at least ${MIN_ARG_COUNT} arguments" 1
  (( $# > 0 )) && __get_opts "$@"

  __dispatch

  return 0
}
(( ${#} > 0 )) && main "${@}" || main
#
# terraform workspace
#  - new dev: create new workspace
#  - list: list workspaces * on currently selected
#  - select dev: slect workspace to move into
#  - show: show the current workspace
#  - delete dev: delete a workspace by name
#
#  Use seperate plan file for workspace
#  terraform plan --var-file="../../terraform.tfvars" -out terraform-dev.tfplan
#
#
