# Qwen3-TTS 0.6B Windows 本地验证 - 使用系统 Python + venv 初始化
# 用法: .\setup_env_venv.ps1

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $scriptDir

$venvDir = "$scriptDir\.venv"

Write-Host "========================================"
Write-Host "Qwen3-TTS 本地验证环境初始化 (venv)"
Write-Host "========================================"

# 检查 Python 版本
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    Write-Error "未找到 python。请先安装 Python 3.10+ 并添加到 PATH。"
    exit 1
}

$version = python --version 2>&1
Write-Host "检测到 Python: $version"

# 简单检查主版本 >= 3.10
$verStr = ($version -replace "Python ", "").Trim()
$major = [int]($verStr.Split(".")[0])
$minor = [int]($verStr.Split(".")[1])
if ($major -lt 3 -or ($major -eq 3 -and $minor -lt 10)) {
    Write-Error "需要 Python 3.10 或更高版本，当前为 $verStr"
    exit 1
}

# 创建虚拟环境
if (Test-Path $venvDir) {
    Write-Host "虚拟环境已存在: $venvDir"
} else {
    Write-Host "创建虚拟环境..."
    python -m venv $venvDir
}

# 激活环境
Write-Host "激活虚拟环境..."
& "$venvDir\Scripts\Activate.ps1"

# 升级 pip
Write-Host "升级 pip..."
python -m pip install --upgrade pip

# 安装 CPU 版 PyTorch（无独立显卡时使用）
Write-Host "安装 CPU 版 PyTorch..."
pip install torch --index-url https://download.pytorch.org/whl/cpu

# 安装其他依赖
Write-Host "安装其他依赖..."
pip install -r requirements-cpu.txt

Write-Host ""
Write-Host "环境初始化完成。"
Write-Host "请运行: .venv\Scripts\Activate.ps1"
Write-Host "然后执行: python download_model.py"
