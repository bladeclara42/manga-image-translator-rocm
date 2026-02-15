#!/bin/bash
# Run manga-image-translator with AMD ROCm GPU support
# This script must be run on a Linux system with ROCm installed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="manga-image-translator-rocm:latest"

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "ERROR: ROCm only works on Linux. Please run this script on a Linux system."
    exit 1
fi

# Check if AMD GPU is available
if [ ! -e /dev/kfd ]; then
    echo "ERROR: /dev/kfd not found. Please ensure ROCm is installed and AMD GPU is available."
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed."
    exit 1
fi

# Build image if it doesn't exist
if ! docker images | grep -q "manga-image-translator-rocm"; then
    echo "Building ROCm Docker image..."
    docker build -f "$SCRIPT_DIR/Dockerfile.rocm" -t "$IMAGE_NAME" "$SCRIPT_DIR"
fi

# Show GPU info
echo "=== AMD GPU Information ==="
docker run --rm --device=/dev/kfd --device=/dev/dri \
    "$IMAGE_NAME" python -c "import torch; print('PyTorch version:', torch.__version__); print('CUDA/ROCm available:', torch.cuda.is_available()); print('Device count:', torch.cuda.device_count()); print('Device name:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'N/A')"

echo ""
echo "=== Running Translation ==="

# Default input/output paths
INPUT_PATH="${1:-$SCRIPT_DIR/image_sample}"
OUTPUT_PATH="${2:-$SCRIPT_DIR/output}"

# Create output directory
mkdir -p "$OUTPUT_PATH"

# Run translation
docker run --rm \
    --device=/dev/kfd \
    --device=/dev/dri \
    --group-add video \
    --group-add render \
    --ipc=host \
    --security-opt seccomp=unconfined \
    -e HSA_OVERRIDE_GFX_VERSION=11.0.0 \
    -e DEEPSEEK_API_KEY="${DEEPSEEK_API_KEY:-sk-66138ac0c4594b3eae7b363624d281fb}" \
    -v "$INPUT_PATH:/app/input:ro" \
    -v "$OUTPUT_PATH:/app/output" \
    "$IMAGE_NAME" \
    local -i /app/input -o /app/output --use-gpu --translator deepseek -v "${@:3}"

echo ""
echo "=== Translation Complete ==="
echo "Output saved to: $OUTPUT_PATH"
