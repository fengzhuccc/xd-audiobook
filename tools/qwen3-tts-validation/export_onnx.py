#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
尝试把 Qwen3-TTS 0.6B 导出为 ONNX 格式。
优先使用 tensorrt-edgellm-export，失败后回退到 torch.onnx.export。
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


def export_with_torch_onnx(model_dir: Path, output_dir: Path) -> bool:
    """回退：用 torch.onnx.export 分别导出 Talker / CodePredictor / Code2Wav。

    注意：这是通用回退方案，可能需要根据 Qwen3-TTS 实际源码调整输入输出。
    """
    try:
        import torch
        import torch.onnx
        from qwen_tts import Qwen3TTSModel
    except ImportError as e:
        print(f"缺少依赖: {e}")
        print("请确认已安装官方包: pip install qwen-tts")
        return False

    print("\n使用 torch.onnx.export 作为回退方案导出...")
    output_dir.mkdir(parents=True, exist_ok=True)

    # 加载模型
    print("加载模型（可能需要几分钟）...")
    try:
        model = Qwen3TTSModel.from_pretrained(
            str(model_dir),
            dtype=torch.float32,
        )
        # Qwen3TTSModel 是包装类，尝试对内部 nn.Module 切 eval 模式
        if hasattr(model, "model") and hasattr(model.model, "eval"):
            model.model.eval()
        elif hasattr(model, "eval"):
            model.eval()
    except Exception as e:
        print(f"加载模型失败: {e}")
        return False

    # Qwen3-TTS 是三个子模块组合。这里仅做占位演示：
    # 实际导出时需要分别定位 model.talker, model.code_predictor, model.code2wav
    # 具体字段名需要查看 Qwen3-TTS 源码或 print(model) 确认。
    submodules = []
    if hasattr(model, "talker"):
        submodules.append(("llm", model.talker))
    if hasattr(model, "code_predictor"):
        submodules.append(("code_predictor", model.code_predictor))
    if hasattr(model, "code2wav"):
        submodules.append(("code2wav", model.code2wav))

    if not submodules:
        print("警告: 未能自动识别 talker / code_predictor / code2wav 子模块。")
        print("请查看模型结构后手动调整本脚本。")
        # 把整个模型作为一个 onnx 导出（通常不是最优，但可作为验证）
        submodules.append(("qwen3_tts_full", model))

    dummy_input = torch.randn(1, 1, 80)  # 占位输入，实际需要 token ids
    for name, module in submodules:
        sub_dir = output_dir / name
        sub_dir.mkdir(parents=True, exist_ok=True)
        onnx_path = sub_dir / "model.onnx"

        print(f"导出 {name} -> {onnx_path}")
        try:
            torch.onnx.export(
                module,
                dummy_input,
                str(onnx_path),
                input_names=["input"],
                output_names=["output"],
                dynamic_axes={"input": {0: "batch"}, "output": {0: "batch"}},
                opset_version=17,
            )
            print(f"  {name} 导出成功")
        except Exception as e:
            print(f"  {name} 导出失败: {e}")
            print("  提示: 占位输入可能不匹配，需要根据实际模型输入维度修改脚本。")

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

    # 方式二：回退
    print("\n尝试回退导出方式...")
    if export_with_torch_onnx(model_dir, output_dir):
        print(f"\n回退导出完成，输出目录: {output_dir}")
        print("注意：回退方式导出的 ONNX 可能需要进一步调整才能用于移动端部署。")
    else:
        print("\nONNX 导出失败。请根据报错信息调整脚本或手动导出。")


if __name__ == "__main__":
    main()
