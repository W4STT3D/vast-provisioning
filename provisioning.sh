#!/usr/bin/env bash
set -euo pipefail

echo "[prov] ===== provisioning start ====="
date

# Vast recommended persistence location
WORKSPACE="${WORKSPACE:-/workspace}"
COMFY_DIR="${WORKSPACE}/ComfyUI"

# Where we stage downloads before moving to final model folders
DL_DIR="${WORKSPACE}/.hf_downloads"

# Model target folders (create both clip_vision and clips_vision just in case the tutorial used a typo)
DIFF_DIR="${COMFY_DIR}/models/diffusion_models"
VAE_DIR="${COMFY_DIR}/models/vae"
CLIPV_DIR="${COMFY_DIR}/models/clip_vision"
CLIPV_DIR_ALT="${COMFY_DIR}/models/clips_vision"
TEXTENC_DIR="${COMFY_DIR}/models/text_encoders"

mkdir -p "${DL_DIR}" "${DIFF_DIR}" "${VAE_DIR}" "${CLIPV_DIR}" "${CLIPV_DIR_ALT}" "${TEXTENC_DIR}"

echo "[prov] activating venv: /venv/main"
# Activate Vast's main Python env
# shellcheck disable=SC1091
. /venv/main/bin/activate

echo "[prov] ensuring huggingface-cli exists (this fixes: huggingface-cli: command not found)"
python -m pip install -U "huggingface_hub[cli]" hf_transfer >/dev/null

# Faster HF downloads when available
export HF_HUB_ENABLE_HF_TRANSFER=1

# Use HF token if provided as env var in Vast template
if [[ -n "${HF_TOKEN:-}" ]]; then
  export HUGGINGFACE_HUB_TOKEN="${HF_TOKEN}"
  echo "[prov] HF_TOKEN detected (auth enabled)"
else
  echo "[prov] HF_TOKEN not set (public downloads only)"
fi

hf_download_file() {
  # Args: repo_id repo_path revision(optional, pass "" for default) out_dir out_name
  local repo_id="$1"
  local repo_path="$2"
  local revision="$3"
  local out_dir="$4"
  local out_name="$5"
  local out_path="${out_dir}/${out_name}"

  if [[ -f "${out_path}" ]]; then
    echo "[prov] exists: ${out_path}"
    return 0
  fi

  echo "[prov] downloading: ${repo_id} :: ${repo_path}"
  mkdir -p "${DL_DIR}"

  # Download into DL_DIR (no symlinks, so it becomes a real file we can move)
  if [[ -n "${revision}" ]]; then
    huggingface-cli download "${repo_id}" "${repo_path}" \
      --revision "${revision}" \
      --local-dir "${DL_DIR}" \
      --local-dir-use-symlinks False
  else
    huggingface-cli download "${repo_id}" "${repo_path}" \
      --local-dir "${DL_DIR}" \
      --local-dir-use-symlinks False
  fi

  # huggingface-cli will mirror paths inside DL_DIR, so we locate the downloaded file
  local found
  found="$(find "${DL_DIR}" -type f -name "$(basename "${repo_path}")" | head -n 1 || true)"

  if [[ -z "${found}" ]]; then
    echo "[prov] ERROR: download finished but file not found in ${DL_DIR}: ${repo_path}"
    return 1
  fi

  mkdir -p "${out_dir}"
  mv -f "${found}" "${out_path}"

  echo "[prov] saved: ${out_path}"
}

echo "[prov] downloading required lip-sync models..."

# 1) Wan14BT2VFusioniX -> diffusion_models
hf_download_file \
  "vrgamedevgirl84/Wan14BT2VFusioniX" \
  "Wan14Bi2vFusioniX.safetensors" \
  "" \
  "${DIFF_DIR}" \
  "Wan14Bi2vFusioniX.safetensors"

# 2) InfiniteTalk single fp8 -> diffusion_models
hf_download_file \
  "Kijai/WanVideo_comfy_fp8_scaled" \
  "InfiniteTalk/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors" \
  "" \
  "${DIFF_DIR}" \
  "Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors"

# 3) Wan 2.1 VAE -> models/vae
hf_download_file \
  "Comfy-Org/Wan_2.1_ComfyUI_repackaged" \
  "split_files/vae/wan_2.1_vae.safetensors" \
  "" \
  "${VAE_DIR}" \
  "wan_2.1_vae.safetensors"

# 4) Clip vision -> models/clip_vision AND models/clips_vision (both)
hf_download_file \
  "Comfy-Org/Wan_2.1_ComfyUI_repackaged" \
  "split_files/clip_vision/clip_vision_h.safetensors" \
  "" \
  "${CLIPV_DIR}" \
  "clip_vision_h.safetensors"

# mirror to the alternate folder name too (some tutorials use clips_vision)
if [[ ! -f "${CLIPV_DIR_ALT}/clip_vision_h.safetensors" ]]; then
  cp -f "${CLIPV_DIR}/clip_vision_h.safetensors" "${CLIPV_DIR_ALT}/clip_vision_h.safetensors"
  echo "[prov] mirrored clip_vision_h.safetensors -> ${CLIPV_DIR_ALT}"
fi

# 5) MelBandRoFormer -> diffusion_models
hf_download_file \
  "Kijai/MelBandRoFormer_comfy" \
  "MelBandRoformer_fp16.safetensors" \
  "" \
  "${DIFF_DIR}" \
  "MelBandRoformer_fp16.safetensors"

# 6) UMT5 text encoder -> text_encoders
# Your link points to a specific commit; we use that as the revision.
hf_download_file \
  "Kijai/WanVideo_comfy" \
  "umt5-xxl-enc-bf16.safetensors" \
  "431c404152d2f589da0326f6b86063f62a6b155c" \
  "${TEXTENC_DIR}" \
  "umt5-xxl-enc-bf16.safetensors"

echo "[prov] ===== provisioning done ====="
date
