#!/usr/bin/env bash
# Qwen3-TTS 0.6B Linux/WSL 本地验证 - 一键运行脚本
# 用法: ./run_all_linux.sh

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

echo "========================================"
echo "Qwen3-TTS 0.6B 本地验证（Linux 一键运行）"
echo "========================================"

# 1. 环境
./setup_env_linux.sh

# 2. 激活环境
source "$SCRIPT_DIR/.venv/bin/activate"

# 3. 下载模型
echo ""
echo "[1/3] 下载模型..."
python download_model.py

# 4. 测试推理
echo ""
echo "[2/3] 测试推理..."
python test_inference.py

# 5. 导出 ONNX（Linux 下同样优先尝试官方工具，没有则打印指引）
echo ""
echo "[3/3] 导出 ONNX..."
python export_onnx.py

echo ""
echo "========================================"
echo "验证流程结束"
echo "========================================"
echo "请查看 outputs/ 和 logs/validation_report.txt"
