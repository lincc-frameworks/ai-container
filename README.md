# Rubin AI Apptainer

This sub-project builds an Apptainer image intended for USDF/S3DF Rubin developers.

## Design choices

- **Fast shell entry**: image + tools are built ahead-of-time; runtime work is mostly bind mounts.
- **Persistent writable state**: a local writable Apptainer overlay (`container/build/overlay.img`) is used so package installs survive across sessions.
- **Safety for shared Rubin state**: `/sdf/group/rubin` and `/sdf/data/rubin` are bind-mounted read-only.
- **Controlled host communication**: `$HOME/rubin-user/container-shared` is bind-mounted RW by default.
- **Credential updates without rebuilds**: auth files and selected env vars are passed at startup.

## Files

- `Apptainer.def`: image build recipe.
- `butler_env_setup.sh`: local copy of the Rubin environment setup helper used at container startup.
- `requirements.txt`: preloaded Python packages for the default Python 3.11 env.
- `scripts/run.sh`: launcher with bind/env policy that always enters via `entrypoint.sh`.
- `scripts/codex-oauth.sh`: browserless-oriented Codex OAuth helper.
- `Makefile`: build/shell/rebuild helpers.

## Build

```bash
make -C container build
```

## Enter shell

```bash
make -C container shell
```

For debugging without entrypoint/LSST setup:

```bash
make -C container shell-raw
```

## Rebuild image + overlay

```bash
make -C container rebuild
```

## Runtime behavior

On shell entry, the container sources `/opt/container/butler_env_setup.sh` which:

- loads LSST from `/sdf/group/rubin/sw/${BUTLER_STACK_VERSION}/loadLSST.sh`
- runs `setup ${BUTLER_SETUP_PACKAGE}` (default: `lsst_distrib`)
- exports Butler + Postgres credential env vars using `~/.lsst/*`

For correctness, `entrypoint.sh` currently uses the simple path and sources
`/opt/container/butler_env_setup.sh` on every container startup.

Interactive shells use a Rubin-style prompt:

`(env-name) [user@hostname-container] /path %`

Override defaults at launch:

```bash
BUTLER_STACK_VERSION=d_latest BUTLER_SETUP_PACKAGE=lsst_sitcom make -C container shell
```

## Auth passthrough

Only selected vars are forwarded from host to container:

- `OPENAI_API_KEY`
- `OPENAI_BASE_URL`
- `ANTHROPIC_API_KEY`
- `ANTHROPIC_BASE_URL`
- `PI_PROVIDER`

Auth/token directories are mounted when present:

- `~/.codex` (RW)
- `~/.config/claude` (RW)
- `~/.pi` (RW)
- `~/.lsst` (RO)

### Codex OAuth (browserless-friendly)

Inside the container, run:

```bash
codex-oauth
```

The helper attempts device-style login if available in the installed Codex CLI.
