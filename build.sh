#!/usr/bin/env bash
set -euo pipefail

# Usage: ./build.sh [left|right|reset|all|update|clean]
# Builds ZMK firmware using Docker. No native Zephyr SDK needed.
# The west workspace is cached in a Docker named volume; first run ~10 min, subsequent ~2 min.

TARGET="${1:-all}"
VOLUME="zmk-charybdis-west"
IMAGE="zmkfirmware/zmk-build-arm:stable"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$REPO_DIR/config"
OUT="$REPO_DIR/firmware"

if ! docker info &>/dev/null; then
  echo "Error: Docker is not running." >&2
  exit 1
fi

mkdir -p "$OUT"

build_shield() {
  local shield="$1"
  echo "==> Building $shield"
  docker run --rm \
    -v "$VOLUME:/workspace" \
    -v "$CONFIG:/workspace/config:ro" \
    -v "$OUT:/out" \
    "$IMAGE" bash -c "
      set -e
      if [ ! -d /workspace/.west ]; then
        echo '--- Initializing west workspace (first run, takes ~10 min) ---'
        cd /workspace
        west init -l config
        west update
      fi
      cd /workspace
      west zephyr-export
      west build -s zmk/app -b nice_nano_v2 --build-dir build/${shield} \
        -- -DSHIELD=${shield} -DZMK_CONFIG=/workspace/config
      cp build/${shield}/zephyr/zmk.uf2 /out/${shield}.uf2
    "
  echo "    -> firmware/${shield}.uf2"
}

case "$TARGET" in
  left)  build_shield charybdis_left ;;
  right) build_shield charybdis_right ;;
  reset) build_shield settings_reset ;;
  all)
    build_shield charybdis_left
    build_shield charybdis_right
    build_shield settings_reset
    ;;
  update)
    echo "==> Updating west modules"
    docker run --rm \
      -v "$VOLUME:/workspace" \
      -v "$CONFIG:/workspace/config:ro" \
      "$IMAGE" bash -c "cd /workspace && west update"
    ;;
  clean)
    echo "==> Removing west workspace volume $VOLUME"
    docker volume rm "$VOLUME" || true
    echo "    Done. Next build will re-initialize from scratch."
    ;;
  *)
    echo "Usage: $0 [left|right|reset|all|update|clean]"
    echo ""
    echo "  left    Build charybdis_left.uf2"
    echo "  right   Build charybdis_right.uf2 (central, trackball)"
    echo "  reset   Build settings_reset.uf2 (clears BLE pairing)"
    echo "  all     Build all three (default)"
    echo "  update  Re-run west update (after changing west.yml)"
    echo "  clean   Delete cached west workspace (forces full re-init)"
    exit 1
    ;;
esac
