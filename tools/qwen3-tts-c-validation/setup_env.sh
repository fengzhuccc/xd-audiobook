#!/usr/bin/env bash
# 安装 WSL2/Linux 编译依赖并克隆纯 C 引擎源码

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

REPO_URL="https://github.com/gabriele-mastrapasqua/qwen3-tts.git"
REPO_DIR="$SCRIPT_DIR/qwen3-tts-c"

echo "========================================"
echo "Qwen3-TTS 纯 C 引擎环境初始化"
echo "========================================"

# 安装系统依赖
echo "安装编译依赖..."
sudo apt update
sudo apt install -y \
    build-essential \
    cmake \
    git \
    libopenblas-dev \
    python3-pip \
    python3-venv \
    wget

# 克隆 C 引擎仓库
if [ -d "$REPO_DIR" ]; then
    echo "源码目录已存在: $REPO_DIR"
    echo "拉取最新代码..."
    cd "$REPO_DIR"
    git pull
else
    echo ""
    echo "克隆纯 C 引擎仓库..."
    git clone "$REPO_URL" "$REPO_DIR"
fi

echo ""
echo "========================================"
echo "环境初始化完成"
echo "========================================"
echo "源码目录: $REPO_DIR"
echo "下一步: ./download_model.sh"
