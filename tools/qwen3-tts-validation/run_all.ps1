# Qwen3-TTS 0.6B Windows 本地验证 - 一键运行脚本
# 用法: .\run_all.ps1

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $scriptDir

Write-Host "========================================"
Write-Host "Qwen3-TTS 0.6B 本地验证（一键运行）"
Write-Host "========================================"

# 1. 环境
.\setup_env.ps1

# 2. 激活环境
$envName = "qwen3-tts"
conda activate $envName

# 3. 下载模型
Write-Host ""
Write-Host "[1/3] 下载模型..."
conda run -n $envName python download_model.py

# 4. 测试推理
Write-Host ""
Write-Host "[2/3] 测试推理..."
conda run -n $envName python test_inference.py

# 5. 导出 ONNX
Write-Host ""
Write-Host "[3/3] 导出 ONNX..."
conda run -n $envName python export_onnx.py

Write-Host ""
Write-Host "========================================"
Write-Host "验证流程结束"
Write-Host "========================================"
Write-Host "请查看 outputs/ 和 logs/validation_report.txt"
