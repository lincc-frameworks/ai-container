#!/usr/bin/env bash

# Source this file on USDF/rubin-devel systems to load an LSST stack
# environment and configure Butler repo aliases/credentials in the way
# described by the repo's bundled USDF notes.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is meant to be sourced, not executed: source butler_env_setup.sh" >&2
    exit 1
fi

# Allow callers to override the stack tag before sourcing the script.
: "${LSST_STACK_VERSION:=w_latest}"

if [[ -n "${LSST_ENV_SETUP_DONE:-}" ]]; then
    echo "lsst_env_setup.sh: LSST environment already initialized."
    return 0
fi

_lsst_load_path="/sdf/group/rubin/sw/${LSST_STACK_VERSION}/loadLSST.sh"
if [[ ! -r "${_lsst_load_path}" ]]; then
    echo "lsst_env_setup.sh: cannot read ${_lsst_load_path}" >&2
    return 1
fi

# USDF shared-stack initialization.
# Docs: lsst-usdf-docs/usdf-stack-access.md
source "${_lsst_load_path}"

# Choose a compatible Science Pipelines package after shared-stack init.
# Docs: lsst-usdf-docs/usdf-stack-access.md
: "${LSST_SETUP_PACKAGE:=lsst_distrib}"
if ! setup "${LSST_SETUP_PACKAGE}"; then
    echo "lsst_env_setup.sh: setup ${LSST_SETUP_PACKAGE} failed" >&2
    return 1
fi

# Use the repo alias file documented for USDF Butler access.
# Docs: lsst-usdf-docs/usdf-data-locations.md
export DAF_BUTLER_REPOSITORY_INDEX="/sdf/group/rubin/shared/data-repos.yaml"

# USDF stores Butler S3 credentials in ~/.lsst instead of ~/.aws.
# Point boto3/ResourcePath there unless the caller already set something else.
export AWS_SHARED_CREDENTIALS_FILE="${AWS_SHARED_CREDENTIALS_FILE:-${HOME}/.lsst/aws-credentials.ini}"

# These credentials are expected to be provisioned automatically after logging
# into the USDF RSP and starting a notebook server.
if [[ ! -r "${HOME}/.lsst/postgres-credentials.txt" ]]; then
    echo "lsst_env_setup.sh: warning: ${HOME}/.lsst/postgres-credentials.txt not found" >&2
fi

if [[ ! -r "${AWS_SHARED_CREDENTIALS_FILE}" ]]; then
    echo "lsst_env_setup.sh: warning: ${AWS_SHARED_CREDENTIALS_FILE} not found" >&2
fi


export PGUSER="rubin"
export PGDATABASE="lsstdb1"
export PGPASSFILE="${HOME}/.lsst/postgres-credentials.txt"
export LSST_ENV_SETUP_DONE=1

echo "Loaded LSST stack from ${_lsst_load_path}"
echo "setup ${LSST_SETUP_PACKAGE}"
echo "DAF_BUTLER_REPOSITORY_INDEX=${DAF_BUTLER_REPOSITORY_INDEX}"
echo "AWS_SHARED_CREDENTIALS_FILE=${AWS_SHARED_CREDENTIALS_FILE}"
echo "PGPASSFILE=${PGPASSFILE}"
