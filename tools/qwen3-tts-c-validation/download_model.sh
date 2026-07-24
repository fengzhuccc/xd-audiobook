#!/usr/bin/env bash
# 下载 Qwen3-TTS 0.6B CustomVoice 模型到 models/ 目录

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

MODEL_ID="Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice"
MODEL_DIR="$SCRIPT_DIR/models/Qwen3-TTS-12Hz-0.6B-CustomVoice"

echo "========================================"
echo "下载 Qwen3-TTS 0.6B 模型"
echo "========================================"

# 检查是否已存在
if [ -d "$MODEL_DIR" ] && [ "$(ls -A "$MODEL_DIR")" ]; then
    echo "模型目录已存在且非空: $MODEL_DIR"
    echo "如需重新下载，请删除该目录后重试。"
    exit 0
fi

# 安装 huggingface_hub 到用户目录或临时虚拟环境
if ! command -v huggingface-cli &> /dev/null; then
    echo "安装 huggingface_hub..."
    pip install --user huggingface_hub || pip install huggingface_hub
fi

mkdir -p "$MODEL_DIR"

echo ""
echo "开始下载模型: $MODEL_ID"
echo "保存路径: $MODEL_DIR"
echo ""

huggingface-cli download "$MODEL_ID" \
    --local-dir "$MODEL_DIR" \
    --local-dir-use-symlinks False

echo ""
echo "========================================"
echo "模型下载完成"
echo "========================================"
echo "下一步: ./build.sh"
