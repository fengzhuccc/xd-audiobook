# Qwen3-TTS 0.6B Windows 本地验证 - 环境初始化脚本
# 用法: .\setup_env.ps1

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $scriptDir

$envName = "qwen3-tts"

Write-Host "========================================"
Write-Host "Qwen3-TTS 本地验证环境初始化"
Write-Host "========================================"

# 检查 conda 是否可用
$conda = Get-Command conda -ErrorAction SilentlyContinue
if (-not $conda) {
    Write-Error "未找到 conda。请先安装 Miniconda 或 Anaconda，并确保 conda 在 PATH 中。"
    exit 1
}

# 检查虚拟环境是否已存在
$envExists = conda env list | Select-String "^$envName\s"
if (-not $envExists) {
    Write-Host "创建 conda 环境: $envName (Python 3.10)"
    conda create -n $envName python=3.10 -y
} else {
    Write-Host "conda 环境 $envName 已存在，跳过创建"
}

Write-Host "激活环境并安装依赖..."
conda run -n $envName pip install --upgrade pip
conda run -n $envName pip install -r requirements.txt

Write-Host ""
Write-Host "环境初始化完成。"
Write-Host "请运行: conda activate $envName"
Write-Host "然后执行: python download_model.py"
