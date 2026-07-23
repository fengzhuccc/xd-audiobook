# Qwen3-TTS 0.6B Windows 本地验证脚本

本目录包含在 Windows PC 上快速验证 Qwen3-TTS 0.6B 模型的脚本。

验证目标：
1. 下载 `Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice` 模型
2. 用 Python 合成一段中文语音，确认模型效果
3. 尝试导出 ONNX（FP16，先不量化）
4. 记录模型体积和推理速度，作为后续鸿蒙集成的参考

## 环境要求

- Windows 10/11
- Python 3.10+（[官方安装包](https://www.python.org/downloads/) 即可，**不需要 conda**）
- 至少 8GB 内存，建议 16GB
- 硬盘空间：预留 10GB
- **显卡不是必须的**：脚本会自动检测是否有 NVIDIA 独立显卡。没有显卡时使用 CPU 运行，速度较慢但能正常工作。

## 快速开始

### 方式一：使用系统 Python + venv（推荐，无需 conda）

用 PowerShell 打开本目录，执行：

```powershell
.\run_all_venv.ps1
```

脚本会自动完成：创建 `.venv` 虚拟环境 → 安装 CPU 版 PyTorch 和其他依赖 → 下载模型 → 合成测试音频 → 尝试导出 ONNX。

### 方式二：使用 conda

如果你已经装了 conda，也可以走 conda 版本：

```powershell
.\run_all.ps1
```

### 方式三：分步执行（venv 版本）

```powershell
# 1. 创建环境并安装依赖
.\setup_env_venv.ps1

# 2. 激活环境
.venv\Scripts\Activate.ps1

# 3. 下载模型
python download_model.py

# 4. 合成测试音频
python test_inference.py

# 5. 导出 ONNX
python export_onnx.py
```

## 输出目录

```
tools/qwen3-tts-validation/
├── models/              # 下载的 HuggingFace 模型
├── outputs/
│   ├── test_qwen_tts.wav    # 测试合成音频
│   └── qwen3_tts_onnx/      # 导出的 ONNX 模型
│       ├── llm/
│       ├── code_predictor/
│       └── code2wav/
└── logs/
    └── validation_report.txt  # 验证报告
```

## 常见问题

### PowerShell 执行策略限制

如果提示「无法加载脚本」，先设置执行策略：

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 模型下载慢

脚本默认从 HuggingFace 下载。如果网络不稳定，可以手动设置镜像：

```powershell
$env:HF_ENDPOINT = "https://hf-mirror.com"
python download_model.py
```

也可以下载到 models/ 目录后重新运行验证脚本。

### ONNX 导出失败

`export_onnx.py` 首先尝试 NVIDIA `tensorrt-edgellm-export`。如果未安装或失败，会回退到通用 `torch.onnx.export` 方式导出三个子模块（Talker / CodePredictor / Code2Wav）。

回退方案可能不是最优 ONNX 图，但足够用来验证鸿蒙部署可行性。

## 下一步

本地验证通过后，请把以下内容反馈给我：

1. `outputs/test_qwen_tts.wav` 的音质感受
2. `logs/validation_report.txt` 里的模型体积、推理耗时
3. `outputs/qwen3_tts_onnx/` 目录下的文件结构截图或列表

我会基于你的导出结果继续写鸿蒙 NAPI 推理层。
