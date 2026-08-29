# ComfyUI + ComfyUI-Manager, CUDA/NVIDIA enabled
# Base: CUDA runtime with cuDNN. Torch's CUDA wheels bundle the CUDA libraries,
# but a CUDA base keeps GPU-compiled custom nodes (installed via Manager) happy.
FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# System deps: python, git, and the libGL/glib libraries many nodes need.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        python3 \
        python3-pip \
        python3-venv \
        libgl1 \
        libglib2.0-0 \
        ffmpeg \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# PyTorch with CUDA support. Override the CUDA channel at build time if needed,
# e.g. --build-arg TORCH_CUDA_CHANNEL=cu121
ARG TORCH_CUDA_CHANNEL=cu124
RUN python3 -m pip install --upgrade pip \
    && python3 -m pip install \
        torch torchvision torchaudio \
        --index-url https://download.pytorch.org/whl/${TORCH_CUDA_CHANNEL}

WORKDIR /opt

# ComfyUI. Pin a specific ref with --build-arg COMFYUI_REF=<tag/commit>.
ARG COMFYUI_REF=master
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /opt/ComfyUI \
    && cd /opt/ComfyUI \
    && git checkout "${COMFYUI_REF}" \
    && python3 -m pip install -r requirements.txt

# ComfyUI-Manager (baked in; entrypoint re-installs it if custom_nodes is mounted empty).
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git \
        /opt/ComfyUI/custom_nodes/ComfyUI-Manager \
    && python3 -m pip install -r /opt/ComfyUI/custom_nodes/ComfyUI-Manager/requirements.txt

WORKDIR /opt/ComfyUI

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8188

ENTRYPOINT ["/entrypoint.sh"]
