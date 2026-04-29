#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
IMAGE="${BUILD_DIR}/rubin-ai.sif"
OVERLAY="${BUILD_DIR}/overlay.img"

if [[ ! -f "${IMAGE}" ]]; then
  echo "Container image not found: ${IMAGE}" >&2
  echo "Run: make build" >&2
  exit 1
fi

if [[ ! -f "${OVERLAY}" ]]; then
  echo "Overlay not found: ${OVERLAY}" >&2
  echo "Run: make build" >&2
  exit 1
fi

# Tiered mount policy (single source of truth):
#   Tier 1 (RW): user-owned work + agent/auth state
#   Tier 2 (RO): shared Rubin trees
#   Tier 3 (none): everything else is not mounted unless explicitly added here
RUBIN_USER_CANONICAL="${RUBIN_USER_CANONICAL:-$(readlink -f "${HOME}/rubin-user" 2>/dev/null || true)}"
if [[ -z "${RUBIN_USER_CANONICAL}" ]]; then
  echo "Unable to resolve ${HOME}/rubin-user; refusing to launch." >&2
  exit 1
fi

RW_BIND_PATHS=(
# Allow read-write to your rubin-user directory so coding agent has access to your
# rubin work. This can be restricted further if needed. See comment.
  "${RUBIN_USER_CANONICAL}:${HOME}/rubin-user:rw"

# Example restricting rw to a single subdirectory:
# "${RUBIN_USER_CANONICAL}/ai-project:${HOME}/rubin-user/ai-project:rw"
 
# Pass through settings directories for preinstalled coding agents
  "${HOME}/.codex:${HOME}/.codex:rw"
  "${HOME}/.claude:${HOME}/.claude:rw"
  "${HOME}/.pi:${HOME}/.pi:rw"
# WARNING: Do not add your ssh config or credential directory to this list, it enables
# a container escape via "ssh localhost"
)

# Enable pass-through auth for claude users so long as they
# perform first login outside the container.
if [[ -f "${HOME}/.claude.json" ]]; then
  RW_BIND_PATHS+=("${HOME}/.claude.json:${HOME}/.claude.json:rw")
fi


RO_BIND_PATHS=(
# Add shared rubin directories read-only to ensure that writes 
# from inside the container cannot affect other users.
  "/sdf/group/rubin:/sdf/group/rubin:ro"
  "/sdf/data/rubin:/sdf/data/rubin:ro"
# WARNING: do not add your ssh config or credential directory to this list
# it enables a container escape via "ssh localhost"
)

if [[ -d "${HOME}/.lsst" ]]; then
  RO_BIND_PATHS+=("${HOME}/.lsst:${HOME}/.lsst:ro")
fi

PASS_ENV=(
  OPENAI_API_KEY
  OPENAI_BASE_URL
  ANTHROPIC_API_KEY
  ANTHROPIC_BASE_URL
  PI_PROVIDER
# WARNING: Do not add any SSH/kerberos/etc credentials to this list.
# it can allow a container escape by the agent.
)

ENV_ARGS=()
for var in "${PASS_ENV[@]}"; do
  if [[ -n "${!var:-}" ]]; then
    ENV_ARGS+=(--env "${var}=${!var}")
  fi
done

BIND_ARGS=()
for bind_spec in "${RO_BIND_PATHS[@]}" "${RW_BIND_PATHS[@]}"; do
  src_path="${bind_spec%%:*}"
  if [[ -e "${src_path}" ]]; then
    BIND_ARGS+=(--bind "${bind_spec}")
  fi
done

COMMON_RUN_FLAGS=(
  --cleanenv   # WARNING: Do not remove, wipes many credentials from your environment, which enable container escapes
  --containall # WARNING: Do not remove, this disables container escapes from manipulating kernel interfaces and /proc filesystem.
  --overlay "${OVERLAY}"
)

APPTAINER_BASE_CMD=(
  apptainer
  exec
  "${COMMON_RUN_FLAGS[@]}"
  "${BIND_ARGS[@]}"
  "${ENV_ARGS[@]}"
  "${IMAGE}"
)
APPTAINER_SHELL_CMD=(
  apptainer
  shell
  "${COMMON_RUN_FLAGS[@]}"
  "${BIND_ARGS[@]}"
  "${ENV_ARGS[@]}"
  "${IMAGE}"
)

if [[ "${RUBIN_RAW_SHELL:-0}" == "1" ]]; then
  exec "${APPTAINER_SHELL_CMD[@]}"
else
  exec "${APPTAINER_BASE_CMD[@]}" /opt/container/entrypoint.sh "$@"
fi

