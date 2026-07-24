#!/usr/bin/env bash
# WSL2 + TensorRT-Edge-LLM 环境安装脚本
# 用于在 RTX 4070 Ti Super 等 NVIDIA 显卡的 WSL2 Ubuntu 中安装官方导出工具
# 用法: ./setup_env_wsl_trt.sh

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

echo "========================================"
echo "WSL2 TensorRT-Edge-LLM 环境安装"
echo "========================================"

# 确认在 WSL2 中
if grep -qEi "Microsoft|WSL" /proc/version &> /dev/null; then
    echo "检测到 WSL2 环境"
else
    echo "警告: 未检测到 WSL2，此脚本主要为 WSL2 设计。"
fi

# 检查 GPU
if ! command -v nvidia-smi &> /dev/null; then
    echo "错误: 未找到 nvidia-smi。请在 Windows 侧安装 NVIDIA 驱动，并确保 WSL2 能识别 GPU。"
    exit 1
fi

echo "GPU 信息:"
nvidia-smi

# 安装系统依赖
echo ""
echo "安装系统依赖..."
sudo apt update
sudo apt install -y python3-pip python3-venv git build-essential cmake

# 创建独立虚拟环境（避免和验证环境冲突）
VENV_DIR="$SCRIPT_DIR/.venv-trt"
if [ -d "$VENV_DIR" ]; then
    echo "虚拟环境已存在: $VENV_DIR"
else
    echo "创建虚拟环境..."
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

# 升级 pip 并安装 PyTorch CUDA 版
echo ""
echo "安装 PyTorch (CUDA)..."
pip install --upgrade pip
pip install torch

# 克隆 TensorRT-Edge-LLM
TRT_DIR="$SCRIPT_DIR/TensorRT-Edge-LLM"
if [ -d "$TRT_DIR" ]; then
    echo "TensorRT-Edge-LLM 目录已存在，拉取最新代码..."
    cd "$TRT_DIR"
    git pull
    git submodule update --init --recursive
else
    echo ""
    echo "克隆 TensorRT-Edge-LLM..."
    git clone https://github.com/NVIDIA/TensorRT-Edge-LLM.git "$TRT_DIR"
    cd "$TRT_DIR"
    git submodule update --init --recursive
fi

# 安装 Python 包
echo ""
echo "安装 TensorRT-Edge-LLM Python 包..."
pip install .

echo ""
echo "========================================"
echo "环境安装完成"
echo "========================================"
echo "请运行: source .venv-trt/bin/activate"
echo "然后执行: ./export_onnx_wsl.sh"
