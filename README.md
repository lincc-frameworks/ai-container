# Rubin AI Apptainer

This sub-project builds an Apptainer image intended for USDF/S3DF Rubin developers wanting to limit the actions taken by coding agents

## Getting Started

1. Clone the repo
2. `make build` to create the container image and overlay fs
3. `make shell` to enter a shell inside the container with latest shared pipelines loaded.
4. Log into your coding agent. `claude`, `codex`, and `pi` are all pre-installed.

## Claude-code specific instructions
Ensure ~/.claude.json exists (`touch ~/.claude.json` is sufficient) prior to starting the container. This will persist logins in your real homedir across container sessions.

## Design choices

- **Fast shell entry**: image + tools are built ahead-of-time; runtime work is mostly bind mounts.
- **LSST shared pipelines**: Loaded by default, configurable with LSST_STACK_VERSION and LSST_SETUP_PACKAGE. See `container-scripts/lsst_env_setup.sh`
- **Persistent writable state**: a local writable Apptainer overlay (`build/overlay.img`) is used so package installs survive across sessions.
- **Safety for shared Rubin state**: `/sdf/group/rubin` and `/sdf/data/rubin` are bind-mounted read-only.
- **Home isolation by default**: launch script uses `--containall` and then bind mounts select paths (see list in `run.sh`)
- **Coding Agent COnvenience**: coding agent settings and env vars are passed through vin bind mounts and en vars

## Files

- `Apptainer.def`: image build recipe.
- `run.sh`: launcher with convigurable bind/env policy, called when you run `make shell`
- `container-scripts/lsst_env_setup.sh`: local copy of the Rubin environment setup helper used at container startup.
- `container-scripts/requirements.txt`: preloaded Python packages for the default Python 3.11 env.
- `container-scripts/codex-oauth.sh`: browserless-oriented Codex OAuth helper.
- `Makefile`: build/shell/rebuild helpers.

## Build

```bash
make build
```

## Enter shell

```bash
make shell
```

For debugging without entrypoint/LSST setup:

```bash
make shell-raw
```

## Runtime behavior

On shell entry, the container sources `/opt/container/lsst_env_setup.sh` which:

- loads LSST from `/sdf/group/rubin/sw/${LSST_STACK_VERSION}/loadLSST.sh`
- runs `setup ${LSST_SETUP_PACKAGE}` (default: `lsst_distrib`)
- exports Butler + Postgres credential env vars using `~/.lsst/*`

For correctness, `entrypoint.sh` currently uses the simple path and sources
`/opt/container/lsst_env_setup.sh` on every container startup.

Interactive shells use a Rubin-style prompt:

`(env-name) [user@hostname-container] /path %`

Override defaults at launch:

```bash
BUTLER_STACK_VERSION=d_latest BUTLER_SETUP_PACKAGE=lsst_sitcom make shell
```

## Auth passthrough

Only selected vars are forwarded from host to container (add/remove in `runs.sh`):

- `OPENAI_API_KEY`
- `OPENAI_BASE_URL`
- `ANTHROPIC_API_KEY`
- `ANTHROPIC_BASE_URL`
- `PI_PROVIDER`

Auth/token directories are mounted when present:

- `~/.codex` (RW)
- `~/.claude` (RW)
- `~/.claude.json` (RW)
- `~/.pi` (RW)
- `~/.lsst` (RO)

Additional bind policy in `scripts/run.sh`:

- Host home directory is not mounted (`--containall`) to block writes via symlink traversal.
- `~/rubin-user` is resolved to its canonical host path and then bound RW to `~/rubin-user` in-container.
- Shared Rubin trees (`/sdf/group/rubin`, `/sdf/data/rubin`) remain mounted RO.
- Mounts are organized as a three-tier policy in one place:
  - Tier 1 (RW): user-owned work + agent/auth state (`~/rubin-user`, `~/.codex`, `~/.claude`, `~/.pi`).
  - Tier 2 (RO): shared Rubin trees.
  - Tier 3 (none): everything else is not mounted unless explicitly listed.
- All Tier 1/Tier 2 bind entries go through the same conditional source-exists processing before being passed to `apptainer`.

### Codex OAuth (browserless-friendly)

Inside the container, run:

```bash
codex-oauth
```

The helper attempts device-style login if available in the installed Codex CLI.
