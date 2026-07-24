# Qwen3-TTS 纯 C 引擎 Windows/WSL 验证

本目录包含在 Windows（通过 WSL2）或 Linux 上快速验证 [gabriele-mastrapasqua/qwen3-tts](https://github.com/gabriele-mastrapasqua/qwen3-tts) 纯 C 推理引擎的脚本。

该引擎的特点：
- 纯 C 实现，无 Python/PyTorch/ONNX Runtime 依赖
- 直接读取 HuggingFace safetensors 权重
- 支持 0.6B / 1.7B 模型自动识别
- 支持流式输出、HTTP 服务、语音克隆

## 推荐验证方式

### 方式一：WSL2（最简单，推荐）

在 Windows 10/11 上启用 WSL2 和 Ubuntu 22.04，然后：

```bash
cd /mnt/d/code/xd-audiobook/tools/qwen3-tts-c-validation
./setup_env.sh
./download_model.sh
./build.sh
./run_inference.sh
```

生成音频位于 `outputs/test_chinese.wav`。

### 方式二：原生 Windows（实验性）

官方标注 Windows/WSL2 为 beta。原生 Windows 需要 MSYS2/MinGW 或自行配置 MSVC + OpenBLAS。
WSL2 已经能满足验证需求，暂不单独提供原生脚本。

## 脚本说明

| 脚本 | 作用 |
|---|---|
| `setup_env.sh` | 安装编译依赖、克隆纯 C 引擎源码 |
| `download_model.sh` | 下载 `Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice` 到 `models/` |
| `build.sh` | 使用 `make blas` 编译出 `qwen_tts` 可执行文件 |
| `run_inference.sh` | 运行一条中文推理，输出 WAV 并打印耗时 |
| `run_server.sh` | 启动本地 HTTP 服务（可选） |

## 模型路径

脚本默认下载到：

```
tools/qwen3-tts-c-validation/models/Qwen3-TTS-12Hz-0.6B-CustomVoice
```

如果你想复用 `tools/qwen3-tts-validation/models/` 下已下载好的模型，可以手动建立软链接：

```bash
ln -s ../qwen3-tts-validation/models/Qwen3-TTS-12Hz-0.6B-CustomVoice \
  models/Qwen3-TTS-12Hz-0.6B-CustomVoice
```

## 评估重点

1. **生成音频质量**：听 `outputs/test_chinese.wav` 是否自然
2. **推理速度**：看脚本输出的 RTF（Real-Time Factor），RTF < 1 表示实时
3. **内存占用**：0.6B BF16 模型约 1.2GB 内存
4. **音色效果**：默认使用 `Serena` 中文音色，可在 `run_inference.sh` 中修改

## 下一步

如果 WSL2 验证效果满意，下一步是：
1. 将该 C 引擎交叉编译为鸿蒙 aarch64 动态库
2. 写 NAPI 封装，暴露 `init(modelPath)`、`synthesize(text, speaker)`、`abort()` 接口
3. 在 ArkTS 的 `TtsService.ets` 中替换 SpeechKit 调用
