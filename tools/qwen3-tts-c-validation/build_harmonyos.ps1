# PowerShell 脚本：交叉编译 Qwen3-TTS C 引擎到 HarmonyOS（aarch64）
# 适用于 Windows + DevEco Studio SDK 环境
# 编译产物: .\qwen3-tts-c-harmonyos\qwen_tts
# 用法: .\build_harmonyos.ps1 [OHOS_SDK_HOME]

param(
    [string]$OhosSdkHome = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = Join-Path $ScriptDir "qwen3-tts-c"
$OutputDir = Join-Path $ScriptDir "qwen3-tts-c-harmonyos"

# 自动探测 SDK 路径
if ([string]::IsNullOrEmpty($OhosSdkHome)) {
    $OhosSdkHome = $env:OHOS_SDK_HOME
}
if ([string]::IsNullOrEmpty($OhosSdkHome)) {
    # 常见默认路径
    $defaultPaths = @(
        "${env:DEVECO_SDK_HOME}",
        "$env:LOCALAPPDATA\Huawei\Sdk",
        "C:\Program Files\Huawei\Sdk"
    )
    foreach ($p in $defaultPaths) {
        if ($p -and (Test-Path $p)) {
            # 找到 openharmony 子目录
            $ohSub = Join-Path $p "openharmony"
            if (Test-Path $ohSub) {
                # 可能有多版本，取最新的
                $versions = Get-ChildItem $ohSub -Directory | Sort-Object Name -Descending
                if ($versions.Count -gt 0) {
                    $OhosSdkHome = $versions[0].FullName
                    break
                }
            }
            $OhosSdkHome = $p
            break
        }
    }
}

if ([string]::IsNullOrEmpty($OhosSdkHome)) {
    Write-Host "错误: 未找到 HarmonyOS SDK。" -ForegroundColor Red
    Write-Host "请通过参数指定: .\build_harmonyos.ps1 'D:\software\DevEco Studio\sdk\default\openharmony'"
    Write-Host "或设置环境变量: `$env:OHOS_SDK_HOME = '...'"
    exit 1
}

if (-not (Test-Path $RepoDir)) {
    Write-Host "错误: 未找到源码目录 $RepoDir" -ForegroundColor Red
    Write-Host "请先运行 .\setup_env.ps1 或 .\setup_env.sh"
    exit 1
}

$ToolchainDir = Join-Path $OhosSdkHome "native\llvm"
if (-not (Test-Path $ToolchainDir)) {
    Write-Host "错误: 未找到 NDK 工具链 $ToolchainDir" -ForegroundColor Red
    Write-Host "请确认 SDK 路径包含 native\llvm 目录"
    exit 1
}

# 查找编译器（Windows 版本带 .exe 后缀）
$compilerNames = @(
    "aarch64-unknown-linux-ohos-clang",
    "aarch64-linux-ohos-clang"
)
$CC = ""
$CXX = ""
foreach ($name in $compilerNames) {
    $ccPath = Join-Path $ToolchainDir "bin\$name.exe"
    $cxxPath = Join-Path $ToolchainDir "bin${name}++.exe"
    if (Test-Path $ccPath) {
        $CC = $ccPath
        $CXX = $cxxPath
        break
    }
}

if ([string]::IsNullOrEmpty($CC)) {
    Write-Host "错误: 未找到 aarch64 编译器" -ForegroundColor Red
    Write-Host "尝试过的路径:"
    foreach ($name in $compilerNames) {
        Write-Host "  $(Join-Path $ToolchainDir "bin\$name.exe")"
    }
    exit 1
}

# 查找 make 工具
$MakeCmd = ""
$makeCandidates = @(
    "make",
    (Join-Path $OhosSdkHome "native\build-tools\bin\make.exe"),
    "${env:DEVECO_STUDIO_HOME}\tools\ninja\ninja.exe"
)
# DevEco Studio 自带的 make 可能在 build-tools 下
$devecoMake = Get-ChildItem -Path (Split-Path (Split-Path $OhosSdkHome)) -Recurse -Filter "make.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($devecoMake) {
    $MakeCmd = $devecoMake.FullName
} else {
    $MakeCmd = "make"  # 假设系统 PATH 里有 make
}

Write-Host "========================================"
Write-Host "交叉编译 Qwen3-TTS C 引擎到 HarmonyOS"
Write-Host "========================================"
Write-Host "源码目录: $RepoDir"
Write-Host "输出目录: $OutputDir"
Write-Host "CC:       $CC"
Write-Host "Make:     $MakeCmd"
Write-Host ""

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

Push-Location $RepoDir

# 清理之前的构建
& $MakeCmd clean 2>$null

# 交叉编译
Write-Host "开始交叉编译 (make blas)..."
& $MakeCmd CC="$CC" CXX="$CXX" CFLAGS="-O2" blas -j4
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "交叉编译失败。常见原因：" -ForegroundColor Red
    Write-Host "1. C 引擎 Makefile 未使用传入的 CC/CXX，需要手动修改 Makefile"
    Write-Host "2. 缺少 OpenBLAS 的 HarmonyOS 交叉编译版本"
    Write-Host "3. 源码中使用了 Linux 特有头文件或 API"
    Write-Host ""
    Write-Host "下一步建议："
    Write-Host "  - 查看 Makefile，确认能否覆盖 CC/CXX"
    Write-Host "  - 如果引擎支持 NO_BLAS 或纯 C 后端，尝试: make NO_BLAS=1 CC=..."
    Pop-Location
    exit 1
}

# 复制产物
$qwenTtsPath = Join-Path $RepoDir "qwen_tts"
if (Test-Path $qwenTtsPath) {
    Copy-Item $qwenTtsPath (Join-Path $OutputDir "qwen_tts") -Force
    Write-Host ""
    Write-Host "========================================"
    Write-Host "编译成功" -ForegroundColor Green
    Write-Host "========================================"
    Write-Host "产物: $(Join-Path $OutputDir 'qwen_tts')"
    Write-Host ""
    Write-Host "下一步:"
    Write-Host "1. 把 qwen_tts 复制到 entry\src\main\resources\rawfile\"
    Write-Host "2. 把模型文件推送到手机"
    Write-Host "3. 在 App 设置里切换到「Qwen 本地语音」"
} else {
    Write-Host "错误: 未找到编译产物 $qwenTtsPath" -ForegroundColor Red
    Pop-Location
    exit 1
}

Pop-Location
