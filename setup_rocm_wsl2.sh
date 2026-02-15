#!/bin/bash
# ============================================================================
# ROCm Setup Script for WSL2 (AMD RX 7000 Series GPUs)
# ============================================================================
# This script sets up ROCm in WSL2 Ubuntu for AMD GPU acceleration.
# Tested with: RX 7700 XT, Ubuntu 22.04/24.04, ROCm 7.2
#
# PREREQUISITES (on Windows):
# 1. Install AMD Adrenalin Edition 26.1.1 for WSL2 (download from AMD website)
# 2. Restart Windows after driver installation
# 3. If ROCm doesn't work, try disabling Secure Boot in BIOS
# ============================================================================

set -e

echo "=============================================="
echo "AMD ROCm Setup for WSL2"
echo "=============================================="

# Check if running in WSL
if ! grep -qi microsoft /proc/version; then
    echo "ERROR: This script must be run inside WSL2 (Ubuntu)"
    exit 1
fi

# Check Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "unknown")
echo "Detected Ubuntu version: $UBUNTU_VERSION"

if [[ "$UBUNTU_VERSION" != "22.04" && "$UBUNTU_VERSION" != "24.04" ]]; then
    echo "WARNING: ROCm WSL2 officially supports Ubuntu 22.04 or 24.04"
    echo "Your version ($UBUNTU_VERSION) may not work correctly."
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "Step 1: Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

echo ""
echo "Step 2: Installing prerequisites..."
sudo apt-get install -y wget gnupg2 software-properties-common

echo ""
echo "Step 3: Adding ROCm repository..."
# Add the ROCm GPG key
wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | sudo apt-key add -

# Add the ROCm repository
echo "deb [arch=amd64] https://repo.radeon.com/rocm/apt/7.2 jammy main" | sudo tee /etc/apt/sources.list.d/rocm.list

# Set the ROCm version preference
echo 'Package: *
Pin: release o=repo.radeon.com
Pin-Priority: 600' | sudo tee /etc/apt/preferences.d/rocm-pin-600

sudo apt-get update

echo ""
echo "Step 4: Installing ROCm ROCr runtime (no DKMS for WSL2)..."
# Note: --no-dkms is required for WSL2 as the amdgpu kernel driver is not used
sudo apt-get install -y rocm-hip-runtime rocminfo rocm-smi-lib

echo ""
echo "Step 5: Setting up environment variables..."
# Add ROCm to PATH
if ! grep -q "ROCm" ~/.bashrc; then
    echo '' >> ~/.bashrc
    echo '# ROCm Configuration' >> ~/.bashrc
    echo 'export PATH=$PATH:/opt/rocm/bin' >> ~/.bashrc
    echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/rocm/lib' >> ~/.bashrc
    echo 'export HSA_OVERRIDE_GFX_VERSION=11.0.0  # For RX 7700 XT (gfx1100)' >> ~/.bashrc
fi

# Source the updated bashrc
export PATH=$PATH:/opt/rocm/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/rocm/lib
export HSA_OVERRIDE_GFX_VERSION=11.0.0

echo ""
echo "Step 6: Verifying ROCm installation..."
echo ""

# Test rocminfo
echo "Running rocminfo..."
if rocminfo 2>/dev/null | grep -q "gfx"; then
    echo "✅ ROCm detected GPU successfully!"
    rocminfo | grep -A 5 "Agent 2"
else
    echo "⚠️  rocminfo did not detect a GPU."
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Make sure you installed AMD Adrenalin Edition 26.1.1 for WSL2 on Windows"
    echo "2. Restart Windows after driver installation"
    echo "3. Try disabling Secure Boot in BIOS (unsigned driver issue)"
    echo "4. Run 'wsl --shutdown' in Windows PowerShell, then restart WSL"
fi

echo ""
echo "=============================================="
echo "Setup Complete!"
echo "=============================================="
echo ""
echo "Next steps:"
echo "1. Close and reopen your WSL terminal"
echo "2. Run 'rocminfo' to verify GPU detection"
echo "3. To use Docker with GPU, run:"
echo "   docker run --device=/dev/kfd --device=/dev/dri ..."
echo ""
echo "For manga-image-translator:"
echo "   cd /path/to/manga-image-translator"
echo "   docker-compose -f docker-compose-rocm.yml up"
echo ""
