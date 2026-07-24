#!/usr/bin/env bash
# 交叉编译 qwen3-tts-c 可执行文件，用于 HarmonyOS（aarch64）。
# 编译产物: ./qwen3-tts-c-harmonyos/qwen_tts
# 用法: ./build_harmonyos.sh <OHOS_SDK_HOME>

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR="$SCRIPT_DIR/qwen3-tts-c"
OUTPUT_DIR="$SCRIPT_DIR/qwen3-tts-c-harmonyos"

OHOS_SDK_HOME="${1:-$OHOS_SDK_HOME}"

if [ -z "$OHOS_SDK_HOME" ]; then
    echo "错误: 请设置 OHOS_SDK_HOME 环境变量，或作为第一个参数传入。"
    echo "例如: ./build_harmonyos.sh /home/user/harmonyos/sdk"
    exit 1
fi

if [ ! -d "$REPO_DIR" ]; then
    echo "错误: 未找到源码目录 $REPO_DIR"
    echo "请先运行 ./setup_env.sh"
    exit 1
fi

TOOLCHAIN_DIR="$OHOS_SDK_HOME/native/llvm"
if [ ! -d "$TOOLCHAIN_DIR" ]; then
    echo "错误: 未找到 NDK 工具链 $TOOLCHAIN_DIR"
    echo "请确认 OHOS_SDK_HOME 指向 HarmonyOS SDK 根目录（包含 native/llvm）"
    exit 1
fi

# 不同版本 SDK 的编译器命名可能不同，优先尝试 common 名称，再回退到 DevEco 实际名称
CC="$TOOLCHAIN_DIR/bin/aarch64-linux-ohos-clang"
CXX="$TOOLCHAIN_DIR/bin/aarch64-linux-ohos-clang++"

if [ ! -f "$CC" ]; then
    CC="$TOOLCHAIN_DIR/bin/aarch64-unknown-linux-ohos-clang"
    CXX="$TOOLCHAIN_DIR/bin/aarch64-unknown-linux-ohos-clang++"
fi

if [ ! -f "$CC" ]; then
    echo "错误: 未找到编译器"
    echo "尝试过的路径:"
    echo "  $TOOLCHAIN_DIR/bin/aarch64-linux-ohos-clang"
    echo "  $TOOLCHAIN_DIR/bin/aarch64-unknown-linux-ohos-clang"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "========================================"
echo "交叉编译 Qwen3-TTS C 引擎到 HarmonyOS"
echo "========================================"
echo "源码目录: $REPO_DIR"
echo "输出目录: $OUTPUT_DIR"
echo "CC:       $CC"
echo ""

cd "$REPO_DIR"

# 清理之前的构建
make clean || true

# 尝试用交叉编译器构建。
# 注意：这里假设 C 引擎 Makefile 支持通过 CC/LDFLAGS 覆盖。
# 如果 Makefile 写死了 gcc，需要先打补丁或改 Makefile。
echo "开始交叉编译..."
make CC="$CC" CXX="$CXX" CFLAGS="-static-libstdc++ -O2" LDFLAGS="-static-libstdc++" -j$(nproc) || {
    echo ""
    echo "交叉编译失败。常见原因："
    echo "1. C 引擎 Makefile 未使用传入的 CC/CXX，需要手动修改 Makefile"
    echo "2. 缺少 OpenBLAS 的 HarmonyOS 交叉编译版本"
    echo "3. 源码中使用了 Linux 特有头文件或 API"
    echo ""
    echo "下一步建议："
    echo "  - 查看 $REPO_DIR/Makefile，确认能否覆盖 CC/CXX"
    echo "  - 如果引擎支持 NO_BLAS 或纯 C 后端，尝试 make NO_BLAS=1 CC=..."
    exit 1
}

# 复制产物
if [ -f "$REPO_DIR/qwen_tts" ]; then
    cp "$REPO_DIR/qwen_tts" "$OUTPUT_DIR/qwen_tts"
    echo ""
    echo "========================================"
    echo "编译成功"
    echo "========================================"
    echo "产物: $OUTPUT_DIR/qwen_tts"
    echo ""
    echo "下一步:"
    echo "1. 把 $OUTPUT_DIR/qwen_tts 复制到 entry/src/main/resources/rawfile/"
    echo "2. 把模型文件复制到手机 /data/.../files/qwen3-tts-model/"
    echo "3. 在 App 设置里切换到「Qwen 本地语音」"
else
    echo "错误: 未找到编译产物 $REPO_DIR/qwen_tts"
    exit 1
fi
