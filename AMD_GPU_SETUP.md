# AMD GPU Setup Guide for manga-image-translator (WSL2 + Docker)

This guide explains how to enable AMD GPU acceleration for manga-image-translator on Windows using WSL2 and Docker Desktop.

## Prerequisites

| Requirement | Details |
|-------------|---------|
| **GPU** | AMD Radeon RX 7000 Series (RX 7700 XT ✅) |
| **Windows** | Windows 10/11 with latest updates |
| **WSL2** | Windows Subsystem for Linux 2 |
| **Docker Desktop** | With WSL2 backend enabled |

---

## Phase 1: Windows Setup

### Step 1: Install AMD WSL2 Driver

> [!IMPORTANT]
> You need a **special AMD driver** that supports WSL2, not the regular Adrenalin driver.

1. Go to [AMD Drivers and Support](https://www.amd.com/en/support)
2. Search for your GPU (RX 7700 XT)
3. Download **"AMD Software: Adrenalin Edition for WSL2"** (version 26.1.1 or later)
   - May be listed as "Radeon Software for WSL" 
4. Install the driver
5. **Restart Windows**

### Step 2: Configure BIOS (if needed)

If ROCm fails to detect your GPU, you may need to:

1. Restart and enter BIOS (usually F2, F12, or Del during boot)
2. **Disable Secure Boot** (the AMD WSL2 driver may be unsigned)
3. Save and exit BIOS

### Step 3: Set up WSL2

```powershell
# Run in PowerShell as Administrator

# Install WSL2 with Ubuntu
wsl --install -d Ubuntu-22.04

# Ensure WSL2 is the default version
wsl --set-default-version 2

# Update WSL
wsl --update
```

### Step 4: Configure Docker Desktop

1. Open Docker Desktop
2. Go to **Settings** → **General**
3. ✅ Ensure **"Use WSL 2 based engine"** is checked
4. Go to **Settings** → **Resources** → **WSL Integration**
5. ✅ Enable integration with your Ubuntu distribution
6. Click **Apply & restart**

---

## Phase 2: WSL2 Ubuntu Setup

Open Ubuntu (WSL2) terminal and run:

### Option A: Use the Automated Script

```bash
# Navigate to the project directory (Windows paths use /mnt/c/...)
cd /mnt/c/Users/bladeclara42/Documents/manga-image-translator

# Make script executable and run
chmod +x setup_rocm_wsl2.sh
./setup_rocm_wsl2.sh
```

### Option B: Manual Installation

```bash
# 1. Update system
sudo apt-get update && sudo apt-get upgrade -y

# 2. Install prerequisites
sudo apt-get install -y wget gnupg2 software-properties-common

# 3. Add ROCm repository
wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | sudo apt-key add -
echo "deb [arch=amd64] https://repo.radeon.com/rocm/apt/7.2 jammy main" | sudo tee /etc/apt/sources.list.d/rocm.list
sudo apt-get update

# 4. Install ROCm (no DKMS for WSL2)
sudo apt-get install -y rocm-hip-runtime rocminfo rocm-smi-lib

# 5. Configure environment
echo 'export PATH=$PATH:/opt/rocm/bin' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/rocm/lib' >> ~/.bashrc
echo 'export HSA_OVERRIDE_GFX_VERSION=11.0.0' >> ~/.bashrc
source ~/.bashrc
```

### Step 5: Verify GPU Detection

```bash
# Test ROCm
rocminfo

# Should show something like:
# Agent 2
#   Name: gfx1100    (this is your RX 7700 XT)
```

If `rocminfo` shows your GPU, you're ready!

---

## Phase 3: Run manga-image-translator

### From WSL2 Terminal

```bash
# Navigate to project
cd /mnt/c/Users/bladeclara42/Documents/manga-image-translator

# Build the ROCm Docker image (if not already built)
docker build -f Dockerfile.rocm -t manga-image-translator-rocm:latest .

# Verify GPU access in container
docker run --rm \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add video \
  --group-add render \
  --ipc=host \
  manga-image-translator-rocm:latest \
  python -c "import torch; print('GPU:', torch.cuda.is_available(), torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'N/A')"

# Run translation with GPU
docker-compose -f docker-compose-rocm.yml up
```

### Using run_rocm.sh

```bash
cd /mnt/c/Users/bladeclara42/Documents/manga-image-translator
chmod +x run_rocm.sh
./run_rocm.sh
```

---

## Troubleshooting

### Problem: `rocminfo` shows no GPU

| Solution | Command/Action |
|----------|----------------|
| Restart WSL | `wsl --shutdown` in PowerShell, then reopen Ubuntu |
| Check driver | Reinstall AMD Adrenalin for WSL2 |
| Disable Secure Boot | Enter BIOS and disable it |
| Check dri devices | `ls -la /dev/dri` (should show `renderD128`) |

### Problem: Docker can't access GPU

```bash
# Ensure you're running Docker from WSL2 terminal, not PowerShell
# Check if devices exist
ls -la /dev/kfd /dev/dri

# Try running with explicit group permissions
docker run --rm \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add $(getent group video | cut -d: -f3) \
  --group-add $(getent group render | cut -d: -f3) \
  --security-opt seccomp=unconfined \
  manga-image-translator-rocm:latest rocminfo
```

### Problem: PyTorch shows `torch.cuda.is_available() = False`

This usually means:
1. ROCm is not properly installed inside the container
2. GPU device passthrough is not working

Try:
```bash
# Inside container, check environment
docker run --rm -it \
  --device=/dev/kfd --device=/dev/dri \
  manga-image-translator-rocm:latest bash

# Then inside:
rocminfo
python -c "import torch; print(torch.cuda.is_available())"
```

---

## Reference: GPU Architecture Codes

| GPU | Architecture | HSA_OVERRIDE_GFX_VERSION |
|-----|--------------|--------------------------|
| RX 7900 XTX | gfx1100 | 11.0.0 |
| RX 7900 XT | gfx1100 | 11.0.0 |
| RX 7800 XT | gfx1101 | 11.0.1 |
| **RX 7700 XT** | **gfx1100** | **11.0.0** |
| RX 7600 | gfx1102 | 11.0.2 |
