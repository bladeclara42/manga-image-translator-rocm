import torch
import sys
import os

print(f"Python version: {sys.version}")
try:
    print(f"PyTorch version: {torch.__version__}")
    print(f"CUDA available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"Device name: {torch.cuda.get_device_name(0)}")
except ImportError:
    print("PyTorch not found")

try:
    from manga_ocr import MangaOcr
    print("Initializing MangaOcr...")
    mocr = MangaOcr()
    print(f"MangaOcr device: {mocr.device}")
except ImportError:
    print("manga_ocr not found")
except Exception as e:
    print(f"Error initializing MangaOcr: {e}")
