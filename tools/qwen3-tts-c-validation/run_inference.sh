#!/usr/bin/env bash
# 运行一次中文推理，输出 WAV 并打印 RTF

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

REPO_DIR="$SCRIPT_DIR/qwen3-tts-c"
MODEL_DIR="$SCRIPT_DIR/models/Qwen3-TTS-12Hz-0.6B-CustomVoice"
OUTPUT_DIR="$SCRIPT_DIR/outputs"
OUTPUT_WAV="$OUTPUT_DIR/test_chinese.wav"

echo "========================================"
echo "Qwen3-TTS 纯 C 引擎推理测试"
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

mkdir -p "$OUTPUT_DIR"

echo ""
echo "模型目录: $MODEL_DIR"
echo "输出文件: $OUTPUT_WAV"
echo ""

# 中文音色可根据 qwen3-tts-c/docs/speaker-map.md 调整
SPEAKER="Serena"
LANGUAGE="Chinese"
TEXT="今天天气真不错，适合出门散步。"

echo "文本: $TEXT"
echo "音色: $SPEAKER"
echo "语言: $LANGUAGE"
echo ""

# 运行推理并计时
START_TIME=$(date +%s.%N)
"$REPO_DIR/qwen_tts" \
    -d "$MODEL_DIR" \
    --text "$TEXT" \
    --speaker "$SPEAKER" \
    --language "$LANGUAGE" \
    -o "$OUTPUT_WAV"
END_TIME=$(date +%s.%N)

ELAPSED=$(echo "$END_TIME - $START_TIME" | bc)

echo ""
echo "========================================"
echo "推理完成"
echo "========================================"
echo "耗时: ${ELAPSED}s"
echo "输出: $OUTPUT_WAV"

# 如果安装了 sox，打印音频时长
if command -v sox &> /dev/null && command -v soxi &> /dev/null; then
    DURATION=$(soxi -D "$OUTPUT_WAV" 2>/dev/null || echo "0")
    if [ "$DURATION" != "0" ]; then
        echo "音频时长: ${DURATION}s"
        RTF=$(echo "$ELAPSED / $DURATION" | bc -l)
        echo "RTF（越低越好）: $RTF"
    fi
else
    echo "提示: 安装 sox 后可自动计算 RTF"
    echo "  sudo apt install -y sox libsox-fmt-all"
fi
