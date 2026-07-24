#!/usr/bin/env bash
# Qwen3-TTS 0.6B Linux/WSL 本地验证 - 环境初始化脚本
# 用法: ./setup_env_linux.sh

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

VENV_DIR="$SCRIPT_DIR/.venv"

echo "========================================"
echo "Qwen3-TTS 本地验证环境初始化 (Linux)"
echo "========================================"

# 检查 Python
if ! command -v python3 &> /dev/null; then
    echo "错误: 未找到 python3。请先安装 Python 3.10+。"
    echo "Ubuntu/Debian: sudo apt update && sudo apt install -y python3 python3-venv python3-pip"
    exit 1
fi

VERSION=$(python3 --version 2>&1 | awk '{print $2}')
echo "检测到 Python: $VERSION"

# 检查主版本 >= 3.10
MAJOR=$(echo "$VERSION" | cut -d. -f1)
MINOR=$(echo "$VERSION" | cut -d. -f2)
if [ "$MAJOR" -lt 3 ] || { [ "$MAJOR" -eq 3 ] && [ "$MINOR" -lt 10 ]; }; then
    echo "错误: 需要 Python 3.10 或更高版本，当前为 $VERSION"
    exit 1
fi

# 创建虚拟环境
if [ -d "$VENV_DIR" ]; then
    echo "虚拟环境已存在: $VENV_DIR"
else
    echo "创建虚拟环境..."
    python3 -m venv "$VENV_DIR"
fi

# 激活环境
source "$VENV_DIR/bin/activate"

# 升级 pip
echo "升级 pip..."
python3 -m pip install --upgrade pip

# 检测是否有 NVIDIA 显卡
if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
    echo "检测到 NVIDIA GPU，安装 CUDA 版 PyTorch..."
    pip install torch
else
    echo "未检测到 GPU，安装 CPU 版 PyTorch（速度较慢）..."
    pip install torch --index-url https://download.pytorch.org/whl/cpu
fi

# 安装其他依赖
echo "安装其他依赖..."
pip install -r requirements-cpu.txt

# Linux 上 SoX 通常通过包管理器安装
if ! command -v sox &> /dev/null; then
    echo ""
    echo "警告: 未检测到 sox 命令。"
    echo "请手动安装 SoX:"
    echo "  Ubuntu/Debian: sudo apt update && sudo apt install -y sox libsox-fmt-all"
    echo "  Fedora: sudo dnf install -y sox"
fi

echo ""
echo "环境初始化完成。"
echo "请运行: source .venv/bin/activate"
echo "然后执行: python download_model.py"
