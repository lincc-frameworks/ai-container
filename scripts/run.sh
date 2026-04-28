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

SHARED_RW_DIR="${RUBIN_CONTAINER_SHARED:-${HOME}/rubin-user/container-shared}"
mkdir -p "${SHARED_RW_DIR}"

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

BIND_ARGS=(
  --bind /sdf/group/rubin:/sdf/group/rubin:ro
  --bind /sdf/data/rubin:/sdf/data/rubin:ro
  --bind "${SHARED_RW_DIR}:${SHARED_RW_DIR}:rw"
)

if [[ -d "${HOME}/.lsst" ]]; then
  BIND_ARGS+=(--bind "${HOME}/.lsst:${HOME}/.lsst:ro")
fi
if [[ -d "${HOME}/.codex" ]]; then
  BIND_ARGS+=(--bind "${HOME}/.codex:${HOME}/.codex:rw")
fi
if [[ -d "${HOME}/.config/claude" ]]; then
  BIND_ARGS+=(--bind "${HOME}/.config/claude:${HOME}/.config/claude:rw")
fi
if [[ -d "${HOME}/.pi" ]]; then
  BIND_ARGS+=(--bind "${HOME}/.pi:${HOME}/.pi:rw")
fi

if [[ $# -gt 0 ]]; then
  exec apptainer exec \
    --cleanenv \
    --overlay "${OVERLAY}" \
    "${BIND_ARGS[@]}" \
    "${ENV_ARGS[@]}" \
    "${IMAGE}" \
    /opt/container/entrypoint.sh "$@"
else
  if [[ "${RUBIN_RAW_SHELL:-0}" == "1" ]]; then
    exec apptainer shell \
      --cleanenv \
      --overlay "${OVERLAY}" \
      "${BIND_ARGS[@]}" \
      "${ENV_ARGS[@]}" \
      "${IMAGE}"
  fi

  exec apptainer exec \
    --cleanenv \
    --overlay "${OVERLAY}" \
    "${BIND_ARGS[@]}" \
    "${ENV_ARGS[@]}" \
    "${IMAGE}" \
    /opt/container/entrypoint.sh
fi
