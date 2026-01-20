#!/usr/bin/env bash
set -euo pipefail

echo "[prov] ===== provisioning start ====="
date

# Vast persistence root
WORKSPACE="${WORKSPACE:-/workspace}"
COMFY_DIR="${WORKSPACE}/ComfyUI"

# Staging area for downloads
DL_DIR="${WORKSPACE}/.hf_downloads"

# Target folders (create both clip_vision + clips_vision to be safe)
DIFF_DIR="${COMFY_DIR}/models/diffusion_models"
VAE_DIR="${COMFY_DIR}/models/vae"
CLIPV_DIR="${COMFY_DIR}/models/clip_vision"
CLIPV_DIR_ALT="${COMFY_DIR}/models/clips_vision"
TEXTENC_DIR="${COMFY_DIR}/models/text_encoders"

mkdir -p "${DL_DIR}" "${DIFF_DIR}" "${VAE_DIR}" "${CLIPV_DIR}" "${CLIPV_DIR_ALT}" "${TEXTENC_DIR}"

echo "[prov] activating venv: /venv/main"
# shellcheck disable=SC1091
. /venv/main/bin/activate

# ---- IMPORTANT: keep huggingface-hub < 1.0 or transformers breaks ----
echo "[prov] installing HF tooling (safe versions)"
python -m pip install -U "huggingface-hub>=0.34.0,<1.0" hf_transfer >/dev/null || true

# Enable faster transfers when possible
export HF_HUB_ENABLE_HF_TRANSFER=1

# Light token detection (doesn't print token)
if [[ -n "${HF_TOKEN:-}" ]]; then
  echo "[prov] HF_TOKEN detected (auth enabled)"
else
  echo "[prov] WARNING: HF_TOKEN not set. Private/gated downloads may fail."
fi

# Helper: download a single file from a repo using python (works even if huggingface-cli is missing)
hf_download_py () {
  local repo_id="$1"
  local filename="$2"
  local out_path="$3"

  python - <<PY
import os
from huggingface_hub import hf_hub_download
token = os.getenv("HF_TOKEN") or True
path = hf_hub_download(
    repo_id="${repo_id}",
    filename="${filename}",
    token=token,
    local_dir=os.path.dirname("${out_path}"),
    local_dir_use_symlinks=False,
    resume_download=True
)
print(path)
PY
}

# Helper: download using huggingface-cli if present, otherwise use python fallback
hf_get () {
  local repo_id="$1"
  local filename="$2"
  local dest_dir="$3"

  mkdir -p "${dest_dir}"

  echo "[prov] downloading: ${repo_id} :: ${filename}"

  if command -v huggingface-cli >/dev/null 2>&1; then
    # Uses HF CLI
    huggingface-cli download "${repo_id}" "${filename}" \
      --local-dir "${DL_DIR}" --local-dir-use-symlinks False \
      --resume-download >/dev/null
    if [[ ! -f "${DL_DIR}/${filename}" ]]; then
      echo "[prov] ERROR: expected downloaded file not found: ${DL_DIR}/${filename}"
      return 1
    fi
    mv -f "${DL_DIR}/${filename}" "${dest_dir}/${filename}"
  else
    # Python fallback (reliable)
    echo "[prov] huggingface-cli not found; using python fallback"
    hf_download_py "${repo_id}" "${filename}" "${DL_DIR}/${filename}" >/dev/null
    if [[ ! -f "${DL_DIR}/${filename}" ]]; then
      echo "[prov] ERROR: expected downloaded file not found: ${DL_DIR}/${filename}"
      return 1
    fi
    mv -f "${DL_DIR}/${filename}" "${dest_dir}/${filename}"
  fi

  echo "[prov] OK: ${dest_dir}/${filename}"
}

echo "[prov] downloading required lip-sync models..."

# 1) Wan14BT2VFusioniX -> diffusion_models
hf_get "vrgamedevgirl84/Wan14BT2VFusioniX" "Wan14Bi2vFusioniX.safetensors" "${DIFF_DIR}"

# 2) Wan2_1-InfiniteTalk-Single_fp8... (repo contains file; you must set exact filename)
# If the file name in that repo differs, update it here to the exact .safetensors name.
hf_get "Kijai/WanVideo_comfy_fp8_scaled" "Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors" "${DIFF_DIR}"

# 3) wan_2.1_vae -> vae
hf_get "Comfy-Org/Wan_2.1_ComfyUI_repackaged" "split_files/vae/wan_2.1_vae.safetensors" "${VAE_DIR}"

# 4) clip_vision_h -> clip_vision (also copy to clips_vision)
hf_get "Comfy-Org/Wan_2.1_ComfyUI_repackaged" "split_files/clip_vision/clip_vision_h.safetensors" "${CLIPV_DIR}"
cp -f "${CLIPV_DIR}/clip_vision_h.safetensors" "${CLIPV_DIR_ALT}/clip_vision_h.safetensors" || true

# 5) MelBandRoFormer -> diffusion_models (confirm exact filename)
hf_get "Kijai/MelBandRoFormer_comfy" "MelBandRoformer_fp16.safetensors" "${DIFF_DIR}"

# 6) umt5-xxl-enc-bf16 -> text_encoders (confirm exact filename)
hf_get "Kijai/WanVideo_comfy" "umt5-xxl-enc-bf16.safetensors" "${TEXTENC_DIR}"

echo "[prov] ===== provisioning complete ====="
date
