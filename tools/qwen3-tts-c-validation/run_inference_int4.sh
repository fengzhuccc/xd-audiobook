#!/usr/bin/env bash
# 运行一次 INT4 量化中文推理，输出 WAV 并打印 RTF

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

REPO_DIR="$SCRIPT_DIR/qwen3-tts-c"
MODEL_DIR="$SCRIPT_DIR/models/Qwen3-TTS-12Hz-0.6B-CustomVoice"
OUTPUT_DIR="$SCRIPT_DIR/outputs"
OUTPUT_WAV="$OUTPUT_DIR/test_chinese_int4.wav"

echo "========================================"
echo "Qwen3-TTS 纯 C 引擎 INT4 量化推理测试"
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

SPEAKER="Serena"
LANGUAGE="Chinese"
TEXT="今天天气真不错，适合出门散步。"

echo "文本: $TEXT"
echo "音色: $SPEAKER"
echo "语言: $LANGUAGE"
echo "量化: INT4（运行时量化）"
echo ""

START_TIME=$(date +%s.%N)
"$REPO_DIR/qwen_tts" \
    -d "$MODEL_DIR" \
    --text "$TEXT" \
    --speaker "$SPEAKER" \
    --language "$LANGUAGE" \
    --int4 \
    -o "$OUTPUT_WAV"
END_TIME=$(date +%s.%N)

ELAPSED=$(echo "$END_TIME - $START_TIME" | bc)

echo ""
echo "========================================"
echo "INT4 量化推理完成"
echo "========================================"
echo "耗时: ${ELAPSED}s"
echo "输出: $OUTPUT_WAV"

if command -v sox &> /dev/null && command -v soxi &> /dev/null; then
    DURATION=$(soxi -D "$OUTPUT_WAV" 2>/dev/null || echo "0")
    if [ "$DURATION" != "0" ]; then
        echo "音频时长: ${DURATION}s"
        RTF=$(echo "$ELAPSED / $DURATION" | bc -l)
        echo "RTF（越低越好）: $RTF"
    fi
fi

echo ""
echo "提示: 可与 outputs/test_chinese.wav（原版 BF16）做 A/B 对比"
echo "注意: 0.6B 模型用 INT4 不一定更快，反而可能因反量化开销变慢"
