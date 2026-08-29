# docker-comfyui

Run [ComfyUI](https://github.com/comfyanonymous/ComfyUI) with
[ComfyUI-Manager](https://github.com/ltdrdata/ComfyUI-Manager) locally in Docker,
using your NVIDIA GPU.

## Requirements

- An NVIDIA GPU + recent driver
- [Docker Engine](https://docs.docker.com/engine/install/) with
  [Docker Compose v2](https://docs.docker.com/compose/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
  installed and configured (`nvidia-ctk runtime configure`)

Verify GPU passthrough works before building:

```bash
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
```

## Usage

```bash
# Build and start (first build pulls PyTorch + ComfyUI, so it takes a while)
docker compose up -d --build

# Follow logs
docker compose logs -f

# Stop
docker compose down
```

Then open **http://localhost:8188**. The **Manager** button appears in the
ComfyUI menu — use it to install custom nodes and download models.

## Data layout

Everything worth keeping is bind-mounted under `./data/` (git-ignored):

| Host path            | Container path                | Contents                    |
|----------------------|-------------------------------|-----------------------------|
| `data/models`        | `/opt/ComfyUI/models`         | checkpoints, LoRAs, VAEs, … |
| `data/output`        | `/opt/ComfyUI/output`         | generated images/videos     |
| `data/input`         | `/opt/ComfyUI/input`          | input images                |
| `data/user`          | `/opt/ComfyUI/user`           | workflows, settings         |
| `data/custom_nodes`  | `/opt/ComfyUI/custom_nodes`   | installed node packs        |

Drop model files into the matching subfolders of `data/models/` (e.g.
`data/models/checkpoints/`).

## Configuration

- **Extra ComfyUI flags** — set `COMFYUI_EXTRA_ARGS` in `docker-compose.yml`,
  e.g. `"--lowvram"`, `"--cpu"`, `"--preview-method auto"`.
- **CUDA channel** — the image installs the `cu124` PyTorch wheels. If your
  driver is older, rebuild with a different channel:
  ```bash
  docker compose build --build-arg TORCH_CUDA_CHANNEL=cu121
  ```
- **Pin ComfyUI version** — build with `--build-arg COMFYUI_REF=<tag-or-commit>`.

## Notes / limitations

- Python packages that custom nodes install (via Manager) live in the image's
  site-packages, which is **not** persisted. If you recreate the container
  (`docker compose up --build`), re-run *Manager → Install missing custom nodes*
  or reinstall the affected packs so their dependencies are present again. The
  node code itself persists in `data/custom_nodes/`.
- The first run downloads several GB (PyTorch + CUDA libs); subsequent starts
  are fast.
