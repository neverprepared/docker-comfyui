# ComfyUI + ComfyUI-Manager, CUDA/NVIDIA enabled
# Base: CUDA runtime with cuDNN. Torch's CUDA wheels bundle the CUDA libraries,
# but a CUDA base keeps GPU-compiled custom nodes (installed via Manager) happy.
FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    # Let uv install into the container's system Python without a venv.
    UV_SYSTEM_PYTHON=1 \
    UV_NO_CACHE=1 \
    UV_BREAK_SYSTEM_PACKAGES=1

# uv: fast Python package installer/resolver (replaces pip).
# Pin a specific tag (e.g. :0.5.11) for reproducible builds.
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# System deps: python, git, and the libGL/glib libraries many nodes need.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        python3 \
        python3-dev \
        python3-pip \
        libgl1 \
        libglib2.0-0 \
        ffmpeg \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# PyTorch with CUDA support. Override the CUDA channel at build time if needed,
# e.g. --build-arg TORCH_CUDA_CHANNEL=cu121
ARG TORCH_CUDA_CHANNEL=cu124
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
