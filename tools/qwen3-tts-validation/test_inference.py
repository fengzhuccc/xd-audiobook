#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
使用 Qwen3-TTS 0.6B 合成一段中文测试音频，并记录推理耗时。
"""

import os
import sys
import time
import shutil
import subprocess
from pathlib import Path

import numpy as np
import soundfile as sf
import torch


def check_sox():
    """检测系统是否已安装 SoX（Qwen3-TTS 在 Windows 上依赖 sox.exe）。"""
    sox_path = shutil.which("sox")
    if sox_path:
        return True

    import platform
    system = platform.system()

    # Windows 上常见安装路径
    if system == "Windows":
        common_paths = [
            r"C:\Program Files (x86)\sox-14-4-2\sox.exe",
            r"C:\Program Files\sox-14-4-2\sox.exe",
        ]
        for p in common_paths:
            if Path(p).exists():
                os.environ["PATH"] = str(Path(p).parent) + os.pathsep + os.environ.get("PATH", "")
                return True

    # Linux/macOS 上常见路径
    common_paths = [
        "/usr/bin/sox",
        "/usr/local/bin/sox",
        "/opt/homebrew/bin/sox",
        "/usr/lib/sox/sox",
    ]
    for p in common_paths:
        if Path(p).exists():
            os.environ["PATH"] = str(Path(p).parent) + os.pathsep + os.environ.get("PATH", "")
            return True

    return False


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
        # Qwen3-TTS 官方包：安装 qwen-tts，导入模块为 qwen_tts
        from qwen_tts import Qwen3TTSModel

        # 自动检测是否有独立显卡，无显卡时使用 CPU + float32
        if torch.cuda.is_available():
            device = "cuda"
            dtype = torch.bfloat16
            print("检测到 CUDA，使用 GPU 加速")
        else:
            device = "cpu"
            dtype = torch.float32
            print("未检测到 CUDA，使用 CPU 运行（速度较慢，但能正常工作）")

        model = Qwen3TTSModel.from_pretrained(
            str(model_dir),
            dtype=dtype,
            device_map="auto" if device == "cuda" else None,
        )
        # 注意：Qwen3TTSModel 是包装类，没有 .to() 方法，
        # device_map=None 时模型默认已在 CPU 上
    except ImportError as e:
        print(f"导入 Qwen3TTSModel 失败: {e}")
        print("\n请确认已安装官方包: pip install qwen-tts")
        sys.exit(1)
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

    # CustomVoice 0.6B 内置中文音色（官方名称）
    # Vivian: 明亮年轻女声
    # Serena: 温柔年轻女声
    # Uncle_Fu: 沉稳男声
    # Dylan: 北京口音年轻男声
    # Eric: 成都口音男声
    speakers = ["Vivian", "Serena"]

    report = {
        "model": "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice",
        "model_dir": str(model_dir),
        "load_time_sec": f"{load_time:.2f}",
        "device": device,
        "samples": [],
    }

    for idx, text in enumerate(test_texts):
        speaker = speakers[idx % len(speakers)]
        print(f"\n[{idx + 1}/{len(test_texts)}] 合成文本: {text}")
        print(f"使用音色: {speaker}")

        try:
            infer_start = time.time()

            # CustomVoice 模型使用 generate_custom_voice
            wavs, sample_rate = model.generate_custom_voice(
                text=text,
                language="Chinese",
                speaker=speaker,
            )

            # wavs 是 list/array，取第一条
            audio = wavs[0] if isinstance(wavs, (list, tuple)) else wavs
            if isinstance(audio, torch.Tensor):
                audio = audio.cpu().float().numpy()
            if audio.ndim > 1:
                audio = audio.squeeze()

            infer_time = time.time() - infer_start
            duration = len(audio) / sample_rate if sample_rate > 0 else 0.0
            rtf = infer_time / duration if duration > 0 else 0.0

            output_wav = output_dir / f"test_qwen_tts_{idx}_{speaker}.wav"
            sf.write(output_wav, audio, sample_rate)

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
    if not check_sox():
        import platform

        print("\n" + "=" * 60)
        print("警告：未检测到 SoX，Qwen3-TTS 需要 sox 命令")
        print("=" * 60)

        if platform.system() == "Windows":
            print("请按以下步骤安装：")
            print("1. 下载 SoX Windows 版：")
            print("   https://sourceforge.net/projects/sox/files/sox/14.4.2/sox-14.4.2-win32.exe")
            print("2. 运行安装程序，记住安装目录（如 C:\\Program Files (x86)\\sox-14-4-2）")
            print("3. 将该目录添加到系统环境变量 PATH")
            print("4. 重新打开 PowerShell，执行: sox --version")
        else:
            print("请按以下步骤安装：")
            print("  Ubuntu/Debian: sudo apt update && sudo apt install -y sox libsox-fmt-all")
            print("  Fedora: sudo dnf install -y sox")
            print("  macOS: brew install sox")
            print("安装后执行: sox --version")

        print("=" * 60 + "\n")
        sys.exit(1)

    main()
