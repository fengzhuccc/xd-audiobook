#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
下载 Qwen3-TTS-12Hz-0.6B-CustomVoice 模型到本地。
"""

import os
import sys
from pathlib import Path

# 允许从 transformers / huggingface_hub 下载
os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS_WARNING", "1")

try:
    from huggingface_hub import snapshot_download
except ImportError:
    print("请先安装依赖: pip install -r requirements.txt")
    sys.exit(1)


def main():
    script_dir = Path(__file__).resolve().parent
    model_dir = script_dir / "models" / "Qwen3-TTS-12Hz-0.6B-CustomVoice"
    model_dir.mkdir(parents=True, exist_ok=True)

    repo_id = "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice"

    print(f"开始下载模型: {repo_id}")
    print(f"保存目录: {model_dir}")
    print("模型大小约 2~3GB，根据网络情况可能需要几分钟到几十分钟。")

    snapshot_download(
        repo_id=repo_id,
        local_dir=str(model_dir),
        local_dir_use_symlinks=False,
        resume_download=True,
    )

    print("\n模型下载完成。")
    print(f"目录: {model_dir}")


if __name__ == "__main__":
    main()
