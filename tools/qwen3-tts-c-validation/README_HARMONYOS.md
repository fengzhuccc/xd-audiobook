# Qwen3-TTS 纯 C 引擎鸿蒙集成说明

## 整体架构

App 侧已经接好 Qwen 引擎开关。流程如下：

```
App (ArkTS)
  ├── 设置页选择「Qwen 本地语音」
  ├── AudioPlayerPage 初始化 TtsService，传入 engineType='qwen'
  ├── QwenTtsEngine 加载 libqwentts.so
  │     └── NAPI 调用 qwen_tts 可执行文件
  └── qwen_tts 读取 models/ 生成 WAV → AVPlayer 播放
```

## 你需要准备的东西

1. **HarmonyOS SDK**（DevEco Studio 自带，或单独下载命令行 SDK）
2. **交叉编译后的 `qwen_tts` 二进制**（aarch64）
3. **模型文件** `Qwen3-TTS-12Hz-0.6B-CustomVoice`

## 步骤

### 1. 获取 HarmonyOS SDK

如果你装了 DevEco Studio，SDK 通常在：

- macOS: `~/Library/Huawei/Sdk`
- Windows: `C:\Users\<用户名>\AppData\Local\Huawei\Sdk`
- Linux: `~/HarmonyOS/Sdk`

需要找到 `native/llvm/bin/aarch64-linux-ohos-clang`。

### 2. 交叉编译 qwen_tts

在 WSL2/Linux 上：

```bash
cd tools/qwen3-tts-c-validation
chmod +x build_harmonyos.sh
./build_harmonyos.sh /path/to/your/HarmonyOS/Sdk
```

成功后产物在 `./qwen3-tts-c-harmonyos/qwen_tts`。

### 3. 把二进制放入 App 资源

```bash
cp qwen3-tts-c-harmonyos/qwen_tts \
   ../../entry/src/main/resources/rawfile/qwen_tts
```

### 4. 把模型文件放到手机

模型太大，不建议打包进 APK。首次安装后通过 hdc 推到手机：

```bash
hdc shell mkdir -p /data/app/el1/bundle/public/<你的bundle名>/files/qwen3-tts-model
hdc file send models/Qwen3-TTS-12Hz-0.6B-CustomVoice \
     /data/app/el1/bundle/public/<你的bundle名>/files/qwen3-tts-model/
```

更优雅的做法是做一个首次启动下载/解压流程，后续可以加上。

### 5. 编译运行 App

重新构建 App。进入听书界面，在设置里切换到「Qwen 本地语音」，即可调用本地模型。

## 已知限制（demo 阶段）

- 每句合成后才播放，没有预加载缓冲
- 语速控制未接入
- 模型文件需要手动放置
- 交叉编译可能需要根据 C 引擎实际 Makefile 调整

## 下一步优化

1. 预加载：当前句播放时后台合成下一句
2. 模型打包/下载：首次启动自动从网络或 assets 解压模型
3. 量化：预先把模型量化到 INT8，减少体积和加载时间
4. 真 NAPI 集成：不通过子进程，直接把 C 引擎函数链进 libqwentts.so
