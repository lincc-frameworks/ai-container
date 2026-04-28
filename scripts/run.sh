#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
IMAGE="${BUILD_DIR}/rubin-ai.sif"
OVERLAY="${BUILD_DIR}/overlay.img"
OVERLAY_SIZE_MB="${OVERLAY_SIZE_MB:-16384}"

mkdir -p "${BUILD_DIR}"

if [[ ! -f "${IMAGE}" ]]; then
  echo "Container image not found: ${IMAGE}" >&2
  echo "Run: make -C ${ROOT_DIR} build" >&2
  exit 1
fi

if [[ ! -f "${OVERLAY}" ]]; then
  apptainer overlay create --size "${OVERLAY_SIZE_MB}" "${OVERLAY}"
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

COMMON_RUN_FLAGS=(
  --cleanenv
  --no-home
  --overlay "${OVERLAY}"
)

RW_BIND_PATHS=(
  "${RUBIN_USER_CANONICAL}:${HOME}/rubin-user:rw"
  "${HOME}/.codex:${HOME}/.codex:rw"
  "${HOME}/.config/claude:${HOME}/.config/claude:rw"
  "${HOME}/.pi:${HOME}/.pi:rw"
)

RO_BIND_PATHS=(
  "/sdf/group/rubin:/sdf/group/rubin:ro"
  "/sdf/data/rubin:/sdf/data/rubin:ro"
)

PASS_ENV=(
  OPENAI_API_KEY
  OPENAI_BASE_URL
  ANTHROPIC_API_KEY
  ANTHROPIC_BASE_URL
  PI_PROVIDER
)

ENV_ARGS=()
for var in "${PASS_ENV[@]}"; do
  if [[ -n "${!var:-}" ]]; then
    ENV_ARGS+=(--env "${var}=${!var}")
  fi
done

BIND_ARGS=()
for bind_spec in "${RW_BIND_PATHS[@]}" "${RO_BIND_PATHS[@]}"; do
  src_path="${bind_spec%%:*}"
  if [[ -e "${src_path}" ]]; then
    BIND_ARGS+=(--bind "${bind_spec}")
  fi
done

if [[ -d "${HOME}/.lsst" ]]; then
  BIND_ARGS+=(--bind "${HOME}/.lsst:${HOME}/.lsst:ro")
fi

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

if [[ $# -gt 0 ]]; then
  exec "${APPTAINER_BASE_CMD[@]}" /opt/container/entrypoint.sh "$@"
else
  if [[ "${RUBIN_RAW_SHELL:-0}" == "1" ]]; then
    exec "${APPTAINER_SHELL_CMD[@]}"
  fi

  exec "${APPTAINER_BASE_CMD[@]}" /opt/container/entrypoint.sh
fi
