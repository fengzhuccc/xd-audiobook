#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
尝试把 Qwen3-TTS 0.6B 导出为 ONNX 格式。

重要说明：
Qwen3-TTS 不是普通的“输入 -> 输出”前馈网络，而是包含三个核心组件：
  1. Talker（自回归 LLM）：文本 -> 第 0 个 codebook token
  2. CodePredictor：预测其余 15 个 codebook token
  3. Code2Wav（声码器）：16 个 codebook -> 波形

官方推荐的导出工具是 NVIDIA TensorRT-Edge-LLM 的 tensorrt-edgellm-export，
它会按正确输入形状分别导出三个子图为 ONNX。

Windows + CPU 环境下通常无法完整走通官方导出，因此本脚本：
  - 优先检测并使用 tensorrt-edgellm-export
  - 检测不到时，给出明确的后续指引，而不是用错误的占位输入反复尝试
"""

import os
import sys
import shutil
import subprocess
from pathlib import Path


def export_with_tensorrt_edgellm(model_dir: Path, output_dir: Path) -> bool:
    """尝试使用 NVIDIA tensorrt-edgellm-export 导出。"""
    cmd = shutil.which("tensorrt-edgellm-export")
    if not cmd:
        print("未找到 tensorrt-edgellm-export，跳过此方式。")
        return False

    repo_id = "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice"
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"使用 tensorrt-edgellm-export 导出 ONNX...")
    print(f"输出目录: {output_dir}")

    try:
        subprocess.run(
            [cmd, repo_id, str(output_dir)],
            check=True,
            cwd=str(model_dir.parent),
        )
        print("tensorrt-edgellm-export 导出成功。")
        return True
    except subprocess.CalledProcessError as e:
        print(f"tensorrt-edgellm-export 导出失败: {e}")
        return False


def inspect_model_structure(model_dir: Path, output_dir: Path) -> bool:
    """加载模型并保存结构信息，供后续手动拆分子模块导出。"""
    try:
        import torch
        from qwen_tts import Qwen3TTSModel
    except ImportError as e:
        print(f"缺少依赖: {e}")
        print("请确认已安装官方包: pip install qwen-tts")
        return False

    print("\n加载模型以获取结构信息（可能需要几分钟）...")
    try:
        model = Qwen3TTSModel.from_pretrained(
            str(model_dir),
            dtype=torch.float32,
        )
    except Exception as e:
        print(f"加载模型失败: {e}")
        return False

    output_dir.mkdir(parents=True, exist_ok=True)
    inspect_path = output_dir / "model_structure.txt"

    with open(inspect_path, "w", encoding="utf-8") as f:
        f.write("Qwen3TTSModel attributes:\n")
        for attr in dir(model):
            if not attr.startswith("_"):
                f.write(f"  - {attr}\n")

        if hasattr(model, "model"):
            inner = model.model
            f.write("\nmodel.model attributes:\n")
            for attr in dir(inner):
                if not attr.startswith("_"):
                    f.write(f"  - {attr}\n")

            f.write("\nmodel.named_modules():\n")
            try:
                for name, _ in inner.named_modules():
                    f.write(f"  {name}\n")
            except Exception as e:
                f.write(f"  无法枚举: {e}\n")

    print(f"模型结构已保存到: {inspect_path}")
    return True


def main():
    script_dir = Path(__file__).resolve().parent
    model_dir = script_dir / "models" / "Qwen3-TTS-12Hz-0.6B-CustomVoice"
    output_dir = script_dir / "outputs" / "qwen3_tts_onnx"

    if not model_dir.exists():
        print(f"模型目录不存在: {model_dir}")
        print("请先运行: python download_model.py")
        sys.exit(1)

    print("========================================")
    print("Qwen3-TTS ONNX 导出")
    print("========================================")

    # 方式一：官方工具
    if export_with_tensorrt_edgellm(model_dir, output_dir):
        print(f"\nONNX 导出完成: {output_dir}")
        return

    # 方式二：保存模型结构并给出指引
    print("\n未找到官方导出工具 tensorrt-edgellm-export。")
    print("Qwen3-TTS 是 Talker + CodePredictor + Code2Wav 三阶段自回归模型，")
    print("无法直接用 torch.onnx.export 导出完整生成流程。")
    print()
    print("推荐方案（按可行性排序）：")
    print()
    print("1. 在 Linux 主机/服务器上安装 TensorRT-Edge-LLM：")
    print("   https://nvidia.github.io/TensorRT-Edge-LLM/latest/user_guide/examples/tts.html")
    print("   执行：tensorrt-edgellm-export Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice <输出目录>")
    print("   这是官方验证过的导出路径，会得到 llm/ code_predictor/ code2wav/ 三个 ONNX。")
    print()
    print("2. 如果要在 HarmonyOS 手机上跑，需要把上述 ONNX 转换为 OM 格式，")
    print("   并针对 NPU 分别优化 Talker（自回归）、CodePredictor、Code2Wav。")
    print()
    print("3. 如果只是想本地验证模型效果，ONNX 导出不是必须的。")
    print("   运行 python test_inference.py 合成音频，确认音色和自然度即可。")
    print()

    inspect_model_structure(model_dir, output_dir)

    print("\n结论：Windows 本地目前无法一键导出可用 ONNX，建议用方案 1 在 Linux 下导出。")


if __name__ == "__main__":
    main()
