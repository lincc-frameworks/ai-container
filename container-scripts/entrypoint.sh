#!/usr/bin/env bash
set -eo pipefail

export PATH="/opt/conda/envs/py311/bin:${PATH}"

# Intentionally use the simple/slow path for correctness:
# always source Butler/LSST setup at container startup.
if [[ -r /opt/container/lsst_env_setup.sh ]]; then
  # shellcheck disable=SC1091
  source /opt/container/lsst_env_setup.sh || true
fi

if [[ $# -eq 0 ]]; then
  prompt_env="${CONDA_DEFAULT_ENV:-lsst}"
  prompt_user="${USER:-$(id -un 2>/dev/null || echo user)}"
  prompt_host="${HOSTNAME:-container}"
  prompt_host="${prompt_host%%.*}-container"
  rcfile="/tmp/rubin-container-rc.$$"
  cat > "${rcfile}" <<EOF
unset PROMPT_COMMAND
PS1='(${prompt_env}) [${prompt_user}@${prompt_host}] \w % '
EOF
  exec /bin/bash --noprofile --rcfile "${rcfile}" -i
else
  exec "$@"
fi
