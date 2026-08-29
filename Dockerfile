# ComfyUI + ComfyUI-Manager, CUDA/NVIDIA enabled
# Base: CUDA runtime with cuDNN. Torch's CUDA wheels bundle the CUDA libraries,
# but a CUDA base keeps GPU-compiled custom nodes (installed via Manager) happy.
FROM nvidia/cuda:12.8.0-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    UV_NO_CACHE=1 \
    UV_PYTHON_INSTALL_DIR=/opt/uv-python \
    # All Python work happens inside this uv-managed venv; put it first on PATH
    # so `python`/`python3`/`pip` resolve to it (incl. ComfyUI-Manager's runtime installs).
    VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:$PATH

# System deps: git, curl (for the uv installer), the libGL/glib libraries many
# nodes need, and ffmpeg. Python itself comes from uv (below), not apt.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        curl \
        libgl1 \
        libglib2.0-0 \
        ffmpeg \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# uv: fast Python package installer/resolver (replaces pip). Installed via the
# official script (avoids ghcr.io registry auth). Pin a version by using a
# versioned URL, e.g. https://astral.sh/uv/0.5.11/install.sh
ADD https://astral.sh/uv/install.sh /uv-installer.sh
RUN UV_INSTALL_DIR=/usr/local/bin sh /uv-installer.sh && rm /uv-installer.sh

# Python 3.13 (ComfyUI's recommended version) via a uv-managed standalone build.
# Override with --build-arg PYTHON_VERSION=3.12 if a node pack needs an older one.
ARG PYTHON_VERSION=3.13
RUN uv venv --python "${PYTHON_VERSION}" "${VIRTUAL_ENV}" \
    && uv pip install pip  # ComfyUI-Manager shells out to pip when installing nodes

# PyTorch with CUDA support. The channel caps the torch version: cu124 tops out
# at torch 2.6.0, whose torch.library.infer_schema rejects PEP 585 builtin
# generics (e.g. `list[int]`). Current ComfyUI master's comfy_kitchen backend
# registers custom ops annotated that way, so it fails to import on 2.6.0.
# Newer torch registers the `list[...]` spellings (verified in 2.10.0); cu128
# provides torch 2.10+. Override if needed, e.g. --build-arg TORCH_CUDA_CHANNEL=cu126.
ARG TORCH_CUDA_CHANNEL=cu128
RUN uv pip install \
        torch torchvision torchaudio \
        --index-url https://download.pytorch.org/whl/${TORCH_CUDA_CHANNEL}

WORKDIR /opt

# ComfyUI. Pin a specific ref with --build-arg COMFYUI_REF=<tag/commit>.
ARG COMFYUI_REF=master
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /opt/ComfyUI \
    && cd /opt/ComfyUI \
    && git checkout "${COMFYUI_REF}" \
    && uv pip install -r requirements.txt

# ComfyUI-Manager (baked in; entrypoint re-installs it if custom_nodes is mounted empty).
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git \
        /opt/ComfyUI/custom_nodes/ComfyUI-Manager \
    && uv pip install -r /opt/ComfyUI/custom_nodes/ComfyUI-Manager/requirements.txt

WORKDIR /opt/ComfyUI

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8188

ENTRYPOINT ["/entrypoint.sh"]
