# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Overview

`docker-comfyui` packages [ComfyUI](https://github.com/comfyanonymous/ComfyUI) +
[ComfyUI-Manager](https://github.com/ltdrdata/ComfyUI-Manager) as a CUDA/NVIDIA
Docker image. It is **infrastructure only** — there is no application source
code, no test suite, no linter, and no package manifest in this repo. The whole
project is 5 files: a Dockerfile, a compose file, an entrypoint script, a GitHub
Actions workflow, and the README.

## Architecture

```
Dockerfile                 -> builds the image (nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04)
entrypoint.sh              -> container ENTRYPOINT; self-heals Manager, execs ComfyUI
docker-compose.yml         -> single `comfyui` service: build args, ports, volumes, GPU reservation
.github/workflows/build.yml-> build-and-push image to GHCR
```

Build pipeline inside the Dockerfile, in order:

1. apt: `git`, `curl`, `libgl1`, `libglib2.0-0`, `ffmpeg`, `ca-certificates`.
2. `uv` installed via `https://astral.sh/uv/install.sh` into `/usr/local/bin`
   (deliberately *not* the `ghcr.io/astral-sh/uv` image — that hit registry auth
   denial).
3. `uv venv` creates the venv at `/opt/venv` (`VIRTUAL_ENV=/opt/venv`, and
   `/opt/venv/bin` is first on `PATH`, so `python`/`pip` resolve there). `pip` is
   installed into the venv because ComfyUI-Manager shells out to it.
4. PyTorch (`torch torchvision torchaudio`) from
   `https://download.pytorch.org/whl/${TORCH_CUDA_CHANNEL}`.
5. ComfyUI cloned to `/opt/ComfyUI` at `${COMFYUI_REF}`, `requirements.txt` installed.
6. ComfyUI-Manager cloned into `/opt/ComfyUI/custom_nodes/ComfyUI-Manager`.

Runtime: `entrypoint.sh` re-clones ComfyUI-Manager if `custom_nodes/` came up as
an empty bind mount (the mount hides the baked-in copy), then
`exec python3 /opt/ComfyUI/main.py --listen 0.0.0.0 --port 8188
$COMFYUI_EXTRA_ARGS "$@"`. Extra args come from `COMFYUI_EXTRA_ARGS` or trailing
`docker compose run` arguments.

Exposed port: **8188** (ComfyUI web UI + its HTTP/WebSocket API).

## Build args

| Arg | Default | Purpose |
|---|---|---|
| `PYTHON_VERSION` | `3.13` | uv-managed standalone Python for the venv |
| `TORCH_CUDA_CHANNEL` | `cu124` | PyTorch wheel index channel (e.g. `cu121`) |
| `COMFYUI_REF` | `master` | ComfyUI git tag/commit to check out |

`docker-compose.yml` sets `TORCH_CUDA_CHANNEL: cu124` and `COMFYUI_REF: master`.

## Key commands

There is no build/test/lint tooling beyond Docker itself.

```bash
# Build + run (this IS the build and the "test")
docker compose up -d --build
docker compose logs -f
docker compose down

# Build only
docker compose build
docker compose build --build-arg TORCH_CUDA_CHANNEL=cu121

# Syntax-check the shell entrypoint
bash -n entrypoint.sh

# Validate the compose file
docker compose config -q
```

UI at http://localhost:8188 once up.

## CI

`.github/workflows/build.yml` (`build-and-push`) triggers on push to `main`, a
weekly cron (`0 6 * * 1`), and `workflow_dispatch`. It frees runner disk space,
sets up Buildx, logs in to GHCR with `GITHUB_TOKEN`, and pushes
`ghcr.io/neverprepared/docker-comfyui` tagged `latest` (default branch), `sha-<short>`,
and `weekly-<YYYYMMDD>` (schedule). Platform is `linux/amd64` only; layer cache is GHA.

**CI does not run on pull requests** — a PR gets no check runs. Verify changes
locally before merging.

## Conventions

- `platform: linux/amd64` is mandatory: CUDA PyTorch wheels are x86_64-only.
  Building on Apple Silicon works (emulated) but cannot use a GPU there.
- Persist state via the `./data/` bind mounts only (`models`, `output`, `input`,
  `user`, `custom_nodes`). `/data/` is git-ignored and `.dockerignore`d.
  Python packages Manager installs are **not** persisted — they live in the image.
- Use `uv pip install` (not bare `pip`) for image-build dependency installs.
- Keep the Dockerfile's ordering: system deps -> uv -> venv -> torch -> ComfyUI ->
  Manager. Moving torch after ComfyUI's `requirements.txt` lets a CPU wheel win.
- `entrypoint.sh` is `set -euo pipefail`; keep it that way and keep the final
  `exec` so ComfyUI is PID 1's replacement and receives signals.
- GPU access needs `nvidia-container-toolkit` on the host; the compose file
  reserves `driver: nvidia, count: all, capabilities: [gpu]`.
- Docs live in `README.md` (user-facing) and this file (agent-facing). `*.md` is
  `.dockerignore`d, so doc edits do not invalidate build cache.
