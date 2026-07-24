#!/usr/bin/env bash
# 启动 Qwen3-TTS 纯 C 引擎 HTTP 服务（可选）

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

REPO_DIR="$SCRIPT_DIR/qwen3-tts-c"
MODEL_DIR="$SCRIPT_DIR/models/Qwen3-TTS-12Hz-0.6B-CustomVoice"
PORT="${1:-8080}"

echo "========================================"
echo "启动 Qwen3-TTS HTTP 服务"
echo "========================================"

if [ ! -f "$REPO_DIR/qwen_tts" ]; then
    echo "错误: 未找到可执行文件 $REPO_DIR/qwen_tts"
    echo "请先运行 ./build.sh"
    exit 1
fi

if [ ! -d "$MODEL_DIR" ]; then
    echo "错误: 未找到模型目录 $MODEL_DIR"
    echo "请先运行 ./download_model.sh"
    exit 1
fi

echo "服务地址: http://localhost:$PORT"
echo "示例请求:"
echo "  curl -X POST http://localhost:$PORT/v1/tts \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"text\":\"你好，世界\",\"speaker\":\"Serena\",\"language\":\"Chinese\"}' \\"
echo "    -o output.wav"
echo ""

"$REPO_DIR/qwen_tts" -d "$MODEL_DIR" --serve "$PORT"
