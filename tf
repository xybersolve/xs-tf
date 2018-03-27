#!/usr/bin/env bash
# ================================================================
# -*- mode: bash -*-
# vi: set ft=sh
# ****************************************************************
#
# DESCRIPTION
#    Script template for full bodied script
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
    Purpose:
    Usage: ${PROGNAME} [-h|--help] [-v|--version]

    Options:
      -h|--help:  help and usage
      -v| --version: show version info

      --var:  show vars in terraform.tfvars file
      --ws=<workspace>: Set workspace
      --init: Run formatted terraform init
      --plan: Run formatted terraform plan
      --apply: Run formatted terraform apply
      --dist: put it in script path directory

    Examples:
      ${PROGNAME} --vars
      ${PROGNAME} --init --ws=prod
      ${PROGNAME} --init -s3 --ws=dev
      ${PROGNAME} --plan --ws=dev
      ${PROGNAME} --apply --ws=dev

EOF
)
# files & directories
declare -r SCRIPT_DIR="$( dirname ${0} )"

# actions
declare -i SET_WORKSPACE=${FALSE}
declare -i INIT=${FALSE}
declare -i PLAN=${FALSE}
declare -i APPLY=${FALSE}
declare -i SHOW_VARS=${FALSE}
declare -i DISTRIBUTE=${FALSE}

# flags
declare -i SIMPLE=${FALSE}
declare -i S3_BACKEND=${FALSE}

# script globals
declare WORKSPACE=''
declare -r WORK_DIR=$(pwd)
declare -r VAR_FILE=$(realpath "${WORK_DIR}/../../terraform.tfvars")
declare PLAN_FILE=''
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

__show_vars() {
  # debug
  echo "Showing var file: ${VAR_FILE}"
  cat "${VAR_FILE}"
}

__init() {
  __check_workspace
  # echo terraform init --var-file="${VAR_FILE}"
  # return 0
  if (( S3_BACKEND )); then
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
  __check_workspace
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
  __check_workspace
  #echo terraform apply "${PLAN_FILE}"
  #return 0
  terraform apply "${PLAN_FILE}"
}

__distribute() {
  cp "${0}" ~/bin
  
}

__get_opts() {
  while (( $# > 0 )); do
    local arg="${1}"; shift;
    case ${arg} in
      --help)    show_help                ;;
      --version) show_version             ;;
      --init)            INIT=${TRUE}     ;;
      --plan)            PLAN=${TRUE}     ;;
      --simple)          SIMPLE=${TRUE}   ;;
      --apply)           APPLY=${TRUE}    ;;
      --vars)        SHOW_VARS=${TRUE}    ;;
      --s3)          S3_BACKEND=${TRUE}   ;;
      --get-workspace) __get_workspace    ;;
      --dist)      DISTRIBUTE=${TRUE}     ;;

      --ws*)
        SET_WORKSPACE=${TRUE}
        [[ ${arg} =~ '=' ]] && WORKSPACE="${arg#*=}"
        ;;
      *) die "Unknown option: ${arg}" ;;
   esac
  done
  return 0
}

__dispatch() {
  (( SET_WORKSPACE )) && __set_workspace
  (( SHOW_VARS )) && __show_vars
  (( INIT )) && __init
  (( PLAN )) && __plan
  (( APPLY )) && __apply
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
