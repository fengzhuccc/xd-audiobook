#!/usr/bin/env bash
# WSL2 + TensorRT-Edge-LLM 导出 Qwen3-TTS ONNX 脚本
# 用法: ./export_onnx_wsl.sh

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

echo "========================================"
echo "Qwen3-TTS ONNX 导出（WSL2 + TensorRT-Edge-LLM）"
echo "========================================"

# 检查虚拟环境
VENV_DIR="$SCRIPT_DIR/.venv-trt"
if [ ! -d "$VENV_DIR" ]; then
    echo "错误: 未找到 .venv-trt 环境。请先运行 ./setup_env_wsl_trt.sh"
    exit 1
fi

source "$VENV_DIR/bin/activate"

# 检查工具
if ! command -v tensorrt-edgellm-export &> /dev/null; then
    echo "错误: 未找到 tensorrt-edgellm-export。请确认 ./setup_env_wsl_trt.sh 已成功执行。"
    exit 1
fi

# 检查 GPU
if ! command -v nvidia-smi &> /dev/null || ! nvidia-smi &> /dev/null; then
    echo "错误: 未检测到 GPU。请确认 Windows 已安装 NVIDIA 驱动且 WSL2 已启用 GPU 支持。"
    exit 1
fi

echo "GPU 信息:"
nvidia-smi

# 设置输出目录
WORKSPACE_DIR="$SCRIPT_DIR/tensorrt-edgellm-workspace"
TTS_MODEL="Qwen3-TTS-12Hz-0.6B-CustomVoice"
ONNX_OUTPUT_DIR="$WORKSPACE_DIR/$TTS_MODEL/onnx"

mkdir -p "$ONNX_OUTPUT_DIR"

echo ""
echo "开始导出 ONNX..."
echo "模型: Qwen/$TTS_MODEL"
echo "输出目录: $ONNX_OUTPUT_DIR"

# 执行导出
tensorrt-edgellm-export "Qwen/$TTS_MODEL" "$ONNX_OUTPUT_DIR"

echo ""
echo "========================================"
echo "ONNX 导出完成"
echo "========================================"
echo "输出目录: $ONNX_OUTPUT_DIR"
echo ""
echo "目录结构预览:"
find "$ONNX_OUTPUT_DIR" -maxdepth 2 -type f | head -20

echo ""
echo "建议将 ONNX 文件复制到 Windows 目录方便使用:"
echo "  cp -r $ONNX_OUTPUT_DIR /mnt/d/qwen3-tts-onnx"
