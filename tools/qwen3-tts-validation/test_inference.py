#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
使用 Qwen3-TTS 0.6B 合成一段中文测试音频，并记录推理耗时。
"""

import os
import sys
import time
import json
from pathlib import Path

import numpy as np
import soundfile as sf
import torch


def write_report(report_path: Path, data: dict):
    report_path.parent.mkdir(parents=True, exist_ok=True)
    with open(report_path, "w", encoding="utf-8") as f:
        for k, v in data.items():
            f.write(f"{k}: {v}\n")


def main():
    script_dir = Path(__file__).resolve().parent
    model_dir = script_dir / "models" / "Qwen3-TTS-12Hz-0.6B-CustomVoice"
    output_dir = script_dir / "outputs"
    output_dir.mkdir(parents=True, exist_ok=True)

    if not model_dir.exists():
        print(f"模型目录不存在: {model_dir}")
        print("请先运行: python download_model.py")
        sys.exit(1)

    print("加载 Qwen3-TTS 模型...")
    start = time.time()

    try:
        # Qwen3-TTS 推荐使用官方 AutoModel / pipeline 加载方式
        # 这里兼容 transformers 通用写法
        from transformers import AutoModel, AutoTokenizer

        # 自动检测是否有独立显卡，无显卡时使用 CPU + float32
        if torch.cuda.is_available():
            device = "cuda"
            torch_dtype = torch.float16
            print("检测到 CUDA，使用 GPU 加速")
        else:
            device = "cpu"
            torch_dtype = torch.float32
            print("未检测到 CUDA，使用 CPU 运行（速度较慢，但能正常工作）")

        model = AutoModel.from_pretrained(
            str(model_dir),
            torch_dtype=torch_dtype,
            device_map="auto" if device == "cuda" else None,
            trust_remote_code=True,
        )
        if device == "cpu":
            model = model.to("cpu")
        tokenizer = AutoTokenizer.from_pretrained(str(model_dir), trust_remote_code=True)
    except Exception as e:
        print(f"模型加载失败: {e}")
        print("\n提示: 如果内存不足，可尝试添加 low_cpu_mem_usage=True")
        sys.exit(1)

    load_time = time.time() - start
    print(f"模型加载完成，耗时: {load_time:.2f}s")

    # 测试文本
    test_texts = [
        "第一章，秋天的早晨，阳光透过窗帘洒进房间。",
        "这是一个关于勇气与成长的故事。",
    ]

    # CustomVoice 内置音色（根据官方文档常见名称）
    speakers = ["ryan", "xiaoyan", "xiaomei"]

    report = {
        "model": "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice",
        "model_dir": str(model_dir),
        "load_time_sec": f"{load_time:.2f}",
        "device": str(next(model.parameters()).device),
        "samples": [],
    }

    for idx, text in enumerate(test_texts):
        speaker = speakers[idx % len(speakers)]
        print(f"\n[{idx + 1}/{len(test_texts)}] 合成文本: {text}")
        print(f"使用音色: {speaker}")

        try:
            infer_start = time.time()

            # Qwen3-TTS 通用推理接口（具体参数以官方 repo 为准）
            # 如果官方提供了 pipeline，可以替换为 pipeline(...)
            inputs = tokenizer(text, return_tensors="pt").to(model.device)
            with torch.no_grad():
                outputs = model.generate(
                    **inputs,
                    speaker=speaker,
                    max_new_tokens=2048,
                )

            # 不同模型返回格式可能不同：numpy array 或 tuple
            if isinstance(outputs, tuple):
                audio = outputs[0]
            else:
                audio = outputs

            if isinstance(audio, torch.Tensor):
                audio = audio.cpu().float().numpy()
            if audio.ndim > 1:
                audio = audio.squeeze()

            infer_time = time.time() - infer_start
            duration = len(audio) / 24000.0  # Qwen3-TTS 默认 24kHz
            rtf = infer_time / duration if duration > 0 else 0.0

            output_wav = output_dir / f"test_qwen_tts_{idx}_{speaker}.wav"
            sf.write(output_wav, audio, 24000)

            print(f"音频长度: {duration:.2f}s, 合成耗时: {infer_time:.2f}s, RTF: {rtf:.3f}")
            print(f"已保存: {output_wav}")

            report["samples"].append({
                "text": text,
                "speaker": speaker,
                "duration_sec": f"{duration:.2f}",
                "infer_time_sec": f"{infer_time:.2f}",
                "rtf": f"{rtf:.3f}",
                "output": str(output_wav),
            })

        except Exception as e:
            print(f"合成失败: {e}")
            report["samples"].append({
                "text": text,
                "speaker": speaker,
                "error": str(e),
            })

    report_path = script_dir / "logs" / "validation_report.txt"
    write_report(report_path, report)
    print(f"\n验证报告已保存: {report_path}")


if __name__ == "__main__":
    main()
