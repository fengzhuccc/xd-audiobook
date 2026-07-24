#!/usr/bin/env bash
# 编译 Qwen3-TTS 纯 C 引擎

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

REPO_DIR="$SCRIPT_DIR/qwen3-tts-c"

echo "========================================"
echo "编译 Qwen3-TTS 纯 C 引擎"
echo "========================================"

if [ ! -d "$REPO_DIR" ]; then
    echo "错误: 未找到源码目录 $REPO_DIR"
    echo "请先运行 ./setup_env.sh"
    exit 1
fi

cd "$REPO_DIR"

echo ""
echo "使用 BLAS 后端编译..."
make clean || true
make blas -j$(nproc)

echo ""
echo "========================================"
echo "编译完成"
echo "========================================"
echo "可执行文件: $REPO_DIR/qwen_tts"
echo ""
echo "下一步: ./run_inference.sh"
