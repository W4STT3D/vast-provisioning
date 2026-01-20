# --- Make sure these dirs exist (including the corrected clip_vision path) ---
mkdir -p "$MODELS_DIR/diffusion_models" "$MODELS_DIR/vae" "$MODELS_DIR/clip_vision" "$MODELS_DIR/clips_vision" "$MODELS_DIR/text_encoders"

# Helper: download a HF file (even if it’s in a subfolder) and place it flat into the destination folder.
hf_get_flat () {
  local repo_id="$1"
  local repo_path="$2"     # can include subfolders, e.g. "InfiniteTalk/file.safetensors"
  local dest_dir="$3"
  local dest_name="${4:-$(basename "$repo_path")}"

  mkdir -p "$dest_dir"

  local outpath="$dest_dir/$dest_name"
  if [ -f "$outpath" ]; then
    echo "[prov] exists: $outpath"
    return 0
  fi

  # download to a persistent cache area (prevents re-downloading if you keep /workspace)
  local dl_root="$WORKSPACE/.hf_downloads"
  mkdir -p "$dl_root"

  echo "[prov] downloading: $repo_id :: $repo_path"
  huggingface-cli download "$repo_id" "$repo_path" \
    --local-dir "$dl_root" \
    --local-dir-use-symlinks False \
    --resume-download

  local downloaded="$dl_root/$repo_path"
  if [ ! -f "$downloaded" ]; then
    echo "[prov] ERROR: expected downloaded file not found: $downloaded"
    exit 1
  fi

  cp -f "$downloaded" "$outpath"
  echo "[prov] saved: $outpath"
}

echo "[prov] downloading required models..."

# 1) Wan14Bi2vFusioniX.safetensors -> models/diffusion_models
hf_get_flat "vrgamedevgirl84/Wan14BT2VFusioniX" \
  "Wan14Bi2vFusioniX.safetensors" \
  "$MODELS_DIR/diffusion_models" \
  "Wan14Bi2vFusioniX.safetensors"

# 2) Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors -> models/diffusion_models (flattened)
hf_get_flat "Kijai/WanVideo_comfy_fp8_scaled" \
  "InfiniteTalk/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors" \
  "$MODELS_DIR/diffusion_models" \
  "Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors"

# 3) wan_2.1_vae.safetensors -> models/vae
hf_get_flat "Comfy-Org/Wan_2.1_ComfyUI_repackaged" \
  "split_files/vae/wan_2.1_vae.safetensors" \
  "$MODELS_DIR/vae" \
  "wan_2.1_vae.safetensors"

# 4) clip_vision_h.safetensors -> models/clip_vision (and also copy to clips_vision just in case your tutorial expects it)
hf_get_flat "Comfy-Org/Wan_2.1_ComfyUI_repackaged" \
  "split_files/clip_vision/clip_vision_h.safetensors" \
  "$MODELS_DIR/clip_vision" \
  "clip_vision_h.safetensors"
cp -f "$MODELS_DIR/clip_vision/clip_vision_h.safetensors" "$MODELS_DIR/clips_vision/clip_vision_h.safetensors" || true

# 5) MelBandRoformer_fp16.safetensors -> models/diffusion_models
hf_get_flat "Kijai/MelBandRoFormer_comfy" \
  "MelBandRoformer_fp16.safetensors" \
  "$MODELS_DIR/diffusion_models" \
  "MelBandRoformer_fp16.safetensors"

# 6) umt5-xxl-enc-bf16.safetensors -> models/text_encoders
hf_get_flat "Kijai/WanVideo_comfy" \
  "umt5-xxl-enc-bf16.safetensors" \
  "$MODELS_DIR/text_encoders" \
  "umt5-xxl-enc-bf16.safetensors"

echo "[prov] model downloads complete."
