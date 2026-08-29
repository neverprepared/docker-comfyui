#!/usr/bin/env bash
set -euo pipefail

COMFYUI_DIR=/opt/ComfyUI

# custom_nodes may be a fresh (empty) bind mount, which hides the baked-in
# Manager. Re-install it so it always survives.
if [ ! -d "${COMFYUI_DIR}/custom_nodes/ComfyUI-Manager" ]; then
    echo "[entrypoint] ComfyUI-Manager not found in custom_nodes; installing..."
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git \
        "${COMFYUI_DIR}/custom_nodes/ComfyUI-Manager"
    uv pip install \
        -r "${COMFYUI_DIR}/custom_nodes/ComfyUI-Manager/requirements.txt" || true
fi

# Extra CLI args can be supplied via COMFYUI_EXTRA_ARGS or `docker compose run ... <args>`.
exec python3 "${COMFYUI_DIR}/main.py" \
    --listen 0.0.0.0 \
    --port 8188 \
    ${COMFYUI_EXTRA_ARGS:-} \
    "$@"
