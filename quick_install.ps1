# FRP Windows一键安装脚本
# 版本: 1.0.0

# 设置TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "========== 开始FRP一键安装 ==========" -ForegroundColor Cyan

# 创建临时目录
$TempDir = "$env:TEMP\frp_install"
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
Set-Location -Path $TempDir

Write-Host "下载FRP安装脚本..." -ForegroundColor Cyan

# 下载批处理文件
try {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Gaoce8888/frp-deploy-tools/main/install_frp_windows.bat" -OutFile "install_frp_windows.bat" -UseBasicParsing
} catch {
    Write-Host "下载失败: $_" -ForegroundColor Red
    exit 1
}

Write-Host "开始安装FRP..." -ForegroundColor Cyan

# 执行批处理文件
& "$TempDir\install_frp_windows.bat"

Write-Host "========== FRP安装完成 ==========" -ForegroundColor Green
Write-Host "配置文件位置: $env:USERPROFILE\frp\conf\frpc.ini" -ForegroundColor Cyan
Write-Host "可通过桌面快捷方式启动FRP客户端或服务端" -ForegroundColor Cyan
