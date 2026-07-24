# PowerShell 脚本：交叉编译 Qwen3-TTS C 引擎到 HarmonyOS（aarch64）
# 适用于 Windows + DevEco Studio SDK 环境（原生 Windows，不需要 WSL2）
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
    $defaultPaths = @(
        "${env:DEVECO_SDK_HOME}",
        "$env:LOCALAPPDATA\Huawei\Sdk",
        "C:\Program Files\Huawei\Sdk"
    )
    foreach ($p in $defaultPaths) {
        if ($p -and (Test-Path $p)) {
            $ohSub = Join-Path $p "openharmony"
            if (Test-Path $ohSub) {
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
    $cxxPath = Join-Path $ToolchainDir "bin\$name++.exe"
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
# DevEco Studio SDK 自带 make.exe
$MakeCmd = ""
$makeSearchPaths = @(
    (Join-Path $OhosSdkHome "native\build-tools\bin\make.exe"),
    (Join-Path $OhosSdkHome "build-tools\bin\make.exe")
)

# 也搜索 DevEco Studio 安装目录下
$devecoPaths = @(
    "${env:DEVECO_STUDIO_HOME}",
    "D:\software\DevEco Studio",
    "C:\Program Files\Huawei\DevEco Studio"
)

foreach ($p in $makeSearchPaths) {
    if (Test-Path $p) {
        $MakeCmd = $p
        break
    }
}

if ([string]::IsNullOrEmpty($MakeCmd)) {
    # 搜索 DevEco Studio 目录
    foreach ($dp in $devecoPaths) {
        if ($dp -and (Test-Path $dp)) {
            $found = Get-ChildItem -Path $dp -Recurse -Filter "make.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) {
                $MakeCmd = $found.FullName
                break
            }
        }
    }
}

if ([string]::IsNullOrEmpty($MakeCmd)) {
    # 尝试系统 PATH 里的 make
    $sysMake = Get-Command make -ErrorAction SilentlyContinue
    if ($sysMake) {
        $MakeCmd = $sysMake.Source
    }
}

if ([string]::IsNullOrEmpty($MakeCmd)) {
    Write-Host "错误: 未找到 make 工具" -ForegroundColor Red
    Write-Host "请安装 make:"
    Write-Host "  choco install make"
    Write-Host "或手动从 DevEco Studio SDK 搜索 make.exe"
    exit 1
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

# 把 SDK bin 目录加到 PATH，让编译器 wrapper 能找到 clang.exe
$sdkBinDir = Join-Path $ToolchainDir "bin"
$env:PATH = "$sdkBinDir;$env:PATH"

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
