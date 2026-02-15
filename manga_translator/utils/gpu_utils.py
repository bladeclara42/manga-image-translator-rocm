"""
GPU Detection Utilities for manga-image-translator

This module provides unified GPU detection across AMD ROCm, NVIDIA CUDA, and Apple MPS.
It normalizes the device detection logic so the application can work seamlessly across
different GPU backends.
"""

import os
import logging
from typing import Optional, Tuple

logger = logging.getLogger('manga_translator')

# Cache for GPU detection results
_gpu_info_cache: Optional[dict] = None


def _detect_gpu_backend() -> dict:
    """
    Detect available GPU backends and cache the result.
    Returns dict with:
        - backend: 'rocm', 'cuda', 'mps', or 'cpu'
        - available: bool
        - device_count: int
        - device_name: str or None
    """
    global _gpu_info_cache
    
    if _gpu_info_cache is not None:
        return _gpu_info_cache
    
    info = {
        'backend': 'cpu',
        'available': False,
        'device_count': 0,
        'device_name': None,
        'is_rocm': False,
        'is_cuda': False,
        'is_mps': False,
    }
    
    try:
        import torch
        
        # Check for Apple MPS (Metal Performance Shaders)
        if hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
            info['backend'] = 'mps'
            info['available'] = True
            info['device_count'] = 1
            info['device_name'] = 'Apple Metal GPU'
            info['is_mps'] = True
        
        # Check for CUDA/ROCm (PyTorch uses cuda API for both)
        elif torch.cuda.is_available():
            device_count = torch.cuda.device_count()
            device_name = torch.cuda.get_device_name(0) if device_count > 0 else None
            
            # Detect if this is ROCm or CUDA based on PyTorch version string
            # ROCm builds have '+rocm' in version string
            is_rocm = 'rocm' in torch.__version__.lower()
            
            # Also check HIP environment variable as fallback
            if not is_rocm and os.environ.get('HIP_VISIBLE_DEVICES') is not None:
                is_rocm = True
            
            # Check for ROCm-specific device names
            if device_name and any(x in device_name.lower() for x in ['amd', 'radeon', 'gfx']):
                is_rocm = True
            
            info['backend'] = 'rocm' if is_rocm else 'cuda'
            info['available'] = True
            info['device_count'] = device_count
            info['device_name'] = device_name
            info['is_rocm'] = is_rocm
            info['is_cuda'] = not is_rocm
            
    except ImportError:
        logger.warning("PyTorch not installed, GPU detection unavailable")
    except Exception as e:
        logger.warning(f"GPU detection failed: {e}")
    
    _gpu_info_cache = info
    return info


def is_gpu_available() -> bool:
    """Check if any GPU (ROCm, CUDA, or MPS) is available."""
    return _detect_gpu_backend()['available']


def is_rocm_available() -> bool:
    """Check if AMD ROCm GPU is available."""
    return _detect_gpu_backend()['is_rocm']


def is_cuda_available() -> bool:
    """Check if NVIDIA CUDA GPU is available."""
    return _detect_gpu_backend()['is_cuda']


def is_mps_available() -> bool:
    """Check if Apple MPS (Metal) is available."""
    return _detect_gpu_backend()['is_mps']


def get_device(use_gpu: bool = True) -> str:
    """
    Get the appropriate device string for PyTorch.
    
    Args:
        use_gpu: Whether to use GPU if available
        
    Returns:
        Device string: 'cuda', 'mps', or 'cpu'
        Note: ROCm uses 'cuda' as the device string in PyTorch
    """
    if not use_gpu:
        return 'cpu'
    
    info = _detect_gpu_backend()
    
    if info['is_mps']:
        return 'mps'
    elif info['is_rocm'] or info['is_cuda']:
        # PyTorch ROCm uses 'cuda' device string
        return 'cuda'
    else:
        return 'cpu'


def get_device_name() -> Optional[str]:
    """Get the name of the GPU device."""
    return _detect_gpu_backend()['device_name']


def get_device_count() -> int:
    """Get the number of available GPU devices."""
    return _detect_gpu_backend()['device_count']


def get_backend_name() -> str:
    """Get the name of the GPU backend (rocm, cuda, mps, or cpu)."""
    return _detect_gpu_backend()['backend']


def clear_gpu_cache():
    """Clear GPU memory cache if available."""
    try:
        import torch
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
    except Exception:
        pass


def print_gpu_info():
    """Log GPU information at startup."""
    info = _detect_gpu_backend()
    
    if info['available']:
        backend_name = info['backend'].upper()
        device_name = info['device_name'] or 'Unknown'
        device_count = info['device_count']
        
        logger.info(f"GPU Backend: {backend_name}")
        logger.info(f"GPU Device: {device_name}")
        logger.info(f"GPU Count: {device_count}")
        
        # Log ROCm-specific info
        if info['is_rocm']:
            hsa_version = os.environ.get('HSA_OVERRIDE_GFX_VERSION', 'not set')
            logger.info(f"HSA_OVERRIDE_GFX_VERSION: {hsa_version}")
    else:
        logger.info("No GPU available, using CPU")


def get_gpu_info_string() -> str:
    """Get a formatted string with GPU information."""
    info = _detect_gpu_backend()
    
    if info['available']:
        return f"{info['backend'].upper()}: {info['device_name']} (x{info['device_count']})"
    else:
        return "CPU only"


def check_gpu_requirements(use_gpu: bool) -> Tuple[bool, str]:
    """
    Check if GPU requirements are met.
    
    Args:
        use_gpu: Whether GPU usage was requested
        
    Returns:
        Tuple of (success, error_message)
    """
    if not use_gpu:
        return True, ""
    
    info = _detect_gpu_backend()
    
    if not info['available']:
        return False, (
            "GPU was requested but no compatible GPU found.\n"
            "Supported GPUs:\n"
            "  - NVIDIA: CUDA-compatible GPU with proper drivers\n"
            "  - AMD: ROCm-compatible GPU (RX 6000/7000 series) with ROCm 6.x\n"
            "  - Apple: M1/M2/M3 series with Metal support\n\n"
            "For AMD GPUs, ensure:\n"
            "  1. ROCm is installed\n"
            "  2. PyTorch ROCm is installed: pip install torch --index-url https://download.pytorch.org/whl/rocm6.2\n"
            "  3. HSA_OVERRIDE_GFX_VERSION is set correctly (e.g., 11.0.0 for RX 7700 XT)"
        )
    
    return True, ""
