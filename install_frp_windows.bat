@echo off
:: FRP Windows安装脚本
:: 作者: Cline
:: 版本: 1.0.0

echo ========== FRP Windows安装脚本 ==========
echo.

setlocal enabledelayedexpansion

:: 设置颜色
set "INFO=[36m[INFO][0m"
set "SUCCESS=[32m[SUCCESS][0m"
set "WARN=[33m[WARN][0m"
set "ERROR=[31m[ERROR][0m"

:: 配置变量
set "FRP_DIR=%USERPROFILE%\frp"
set "TEMP_DIR=%FRP_DIR%\temp"
set "LOG_FILE=%FRP_DIR%\install.log"
set "FRP_VERSION=0.51.3"
set "ARCH=amd64"
set "OS=windows"
set "DOWNLOAD_RETRY=3"

:: 下载源
set "PRIMARY_SOURCE=https://github.com/fatedier/frp/releases/download"
set "BACKUP_SOURCE_1=https://download.fastgit.org/fatedier/frp/releases/download"
set "BACKUP_SOURCE_2=https://mirror.ghproxy.com/https://github.com/fatedier/frp/releases/download"

:: 创建所需目录
echo %INFO% 创建必要目录...
if not exist "%FRP_DIR%" mkdir "%FRP_DIR%"
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"
if not exist "%FRP_DIR%\conf" mkdir "%FRP_DIR%\conf"
if not exist "%FRP_DIR%\logs" mkdir "%FRP_DIR%\logs"

:: 记录安装信息
echo [INFO] %date% %time% - 开始安装FRP v%FRP_VERSION% for %OS%-%ARCH% > "%LOG_FILE%"

:: 检查PowerShell可用性
echo %INFO% 检查PowerShell...
where powershell >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo %ERROR% PowerShell未找到，无法继续安装
    echo [ERROR] %date% %time% - PowerShell未找到 >> "%LOG_FILE%"
    exit /b 1
)

:: 定义下载函数
echo %INFO% 准备下载FRP...
set "FILENAME=frp_%FRP_VERSION%_%OS%_%ARCH%.zip"
set "TARGET_FILE=%TEMP_DIR%\%FILENAME%"

:: 检查文件是否已存在
if exist "%TARGET_FILE%" (
    echo %INFO% 文件已存在，跳过下载: %TARGET_FILE%
    goto :extract
)

:: 尝试从主源下载
echo %INFO% 从主源下载 FRP v%FRP_VERSION%...
echo [INFO] %date% %time% - 尝试从主源下载 >> "%LOG_FILE%"

powershell -Command "$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri '%PRIMARY_SOURCE%/v%FRP_VERSION%/%FILENAME%' -OutFile '%TARGET_FILE%' -UseBasicParsing"
if %ERRORLEVEL% EQU 0 goto :download_success

echo %WARN% 主源下载失败，尝试备用源1...
echo [WARN] %date% %time% - 主源下载失败，尝试备用源1 >> "%LOG_FILE%"

powershell -Command "$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri '%BACKUP_SOURCE_1%/v%FRP_VERSION%/%FILENAME%' -OutFile '%TARGET_FILE%' -UseBasicParsing"
if %ERRORLEVEL% EQU 0 goto :download_success

echo %WARN% 备用源1下载失败，尝试备用源2...
echo [WARN] %date% %time% - 备用源1下载失败，尝试备用源2 >> "%LOG_FILE%"

powershell -Command "$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri '%BACKUP_SOURCE_2%/v%FRP_VERSION%/%FILENAME%' -OutFile '%TARGET_FILE%' -UseBasicParsing"
if %ERRORLEVEL% EQU 0 goto :download_success

echo %ERROR% 所有下载源都失败了！
echo [ERROR] %date% %time% - 所有下载源都失败 >> "%LOG_FILE%"
echo %INFO% 请手动下载FRP并将zip文件放在 %TARGET_FILE% 位置
pause
exit /b 1

:download_success
echo %SUCCESS% 下载完成: %TARGET_FILE%
echo [SUCCESS] %date% %time% - 下载完成 >> "%LOG_FILE%"

:extract
echo %INFO% 解压FRP文件...
echo [INFO] %date% %time% - 开始解压文件 >> "%LOG_FILE%"

powershell -Command "Expand-Archive -Path '%TARGET_FILE%' -DestinationPath '%TEMP_DIR%' -Force"
if %ERRORLEVEL% NEQ 0 (
    echo %ERROR% 解压失败！
    echo [ERROR] %date% %time% - 解压失败 >> "%LOG_FILE%"
    exit /b 1
)

echo %SUCCESS% 解压完成
echo [SUCCESS] %date% %time% - 解压完成 >> "%LOG_FILE%"

:: 复制文件到目标目录
echo %INFO% 安装FRP...
echo [INFO] %date% %time% - 复制文件到安装目录 >> "%LOG_FILE%"

set "EXTRACTED_DIR=%TEMP_DIR%\frp_%FRP_VERSION%_%OS%_%ARCH%"

:: 复制二进制文件
copy /Y "%EXTRACTED_DIR%\frpc.exe" "%FRP_DIR%\" >nul
copy /Y "%EXTRACTED_DIR%\frps.exe" "%FRP_DIR%\" >nul

:: 复制配置文件（如果目标不存在）
for %%F in ("%EXTRACTED_DIR%\*.ini") do (
    set "CONFIG_NAME=%%~nxF"
    if not exist "%FRP_DIR%\conf\!CONFIG_NAME!" (
        copy /Y "%%F" "%FRP_DIR%\conf\" >nul
        echo %INFO% 复制配置文件: !CONFIG_NAME!
    ) else (
        echo %INFO% 配置文件已存在，跳过: !CONFIG_NAME!
    )
)

echo %SUCCESS% FRP安装完成！
echo [SUCCESS] %date% %time% - 安装完成 >> "%LOG_FILE%"

:: 创建快捷方式
echo %INFO% 创建Windows服务脚本...
echo [INFO] %date% %time% - 创建服务脚本 >> "%LOG_FILE%"

:: 创建客户端服务脚本
echo @echo off > "%FRP_DIR%\install_frpc_service.bat"
echo :: FRP客户端Windows服务安装脚本 >> "%FRP_DIR%\install_frpc_service.bat"
echo echo 安装FRP客户端Windows服务... >> "%FRP_DIR%\install_frpc_service.bat"
echo cd /d "%FRP_DIR%" >> "%FRP_DIR%\install_frpc_service.bat"
echo sc create frpc binPath= "\"%FRP_DIR%\frpc.exe\" -c \"%FRP_DIR%\conf\frpc.ini\"" start= auto >> "%FRP_DIR%\install_frpc_service.bat"
echo sc description frpc "FRP Client Service" >> "%FRP_DIR%\install_frpc_service.bat"
echo sc start frpc >> "%FRP_DIR%\install_frpc_service.bat"
echo echo FRP客户端服务已安装并启动。 >> "%FRP_DIR%\install_frpc_service.bat"
echo pause >> "%FRP_DIR%\install_frpc_service.bat"

:: 创建服务端服务脚本
echo @echo off > "%FRP_DIR%\install_frps_service.bat"
echo :: FRP服务端Windows服务安装脚本 >> "%FRP_DIR%\install_frps_service.bat"
echo echo 安装FRP服务端Windows服务... >> "%FRP_DIR%\install_frps_service.bat"
echo cd /d "%FRP_DIR%" >> "%FRP_DIR%\install_frps_service.bat"
echo sc create frps binPath= "\"%FRP_DIR%\frps.exe\" -c \"%FRP_DIR%\conf\frps.ini\"" start= auto >> "%FRP_DIR%\install_frps_service.bat"
echo sc description frps "FRP Server Service" >> "%FRP_DIR%\install_frps_service.bat"
echo sc start frps >> "%FRP_DIR%\install_frps_service.bat"
echo echo FRP服务端服务已安装并启动。 >> "%FRP_DIR%\install_frps_service.bat"
echo pause >> "%FRP_DIR%\install_frps_service.bat"

:: 创建客户端启动脚本
echo @echo off > "%FRP_DIR%\start_frpc.bat"
echo :: FRP客户端启动脚本 >> "%FRP_DIR%\start_frpc.bat"
echo echo 正在启动FRP客户端... >> "%FRP_DIR%\start_frpc.bat"
echo cd /d "%FRP_DIR%" >> "%FRP_DIR%\start_frpc.bat"
echo start "FRP客户端" frpc.exe -c "%FRP_DIR%\conf\frpc.ini" >> "%FRP_DIR%\start_frpc.bat"
echo echo FRP客户端已启动。 >> "%FRP_DIR%\start_frpc.bat"

:: 创建服务端启动脚本
echo @echo off > "%FRP_DIR%\start_frps.bat"
echo :: FRP服务端启动脚本 >> "%FRP_DIR%\start_frps.bat"
echo echo 正在启动FRP服务端... >> "%FRP_DIR%\start_frps.bat"
echo cd /d "%FRP_DIR%" >> "%FRP_DIR%\start_frps.bat"
echo start "FRP服务端" frps.exe -c "%FRP_DIR%\conf\frps.ini" >> "%FRP_DIR%\start_frps.bat"
echo echo FRP服务端已启动。 >> "%FRP_DIR%\start_frps.bat"

echo %INFO% 创建桌面快捷方式...
set "DESKTOP=%USERPROFILE%\Desktop"

:: 创建FRP文件夹快捷方式
powershell -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%DESKTOP%\FRP文件夹.lnk'); $Shortcut.TargetPath = '%FRP_DIR%'; $Shortcut.Save()"

:: 创建客户端启动快捷方式
powershell -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%DESKTOP%\启动FRP客户端.lnk'); $Shortcut.TargetPath = '%FRP_DIR%\start_frpc.bat'; $Shortcut.WorkingDirectory = '%FRP_DIR%'; $Shortcut.Save()"

echo %SUCCESS% 安装过程完成！
echo.
echo %INFO% FRP已安装到: %FRP_DIR%
echo %INFO% 配置文件位于: %FRP_DIR%\conf\
echo %INFO% 桌面快捷方式已创建。
echo.
echo %INFO% 使用说明:
echo   1. 编辑 %FRP_DIR%\conf\frpc.ini 配置文件
echo   2. 运行桌面上的"启动FRP客户端"快捷方式或
echo      运行 %FRP_DIR%\install_frpc_service.bat 安装为Windows服务
echo.
echo [SUCCESS] %date% %time% - 安装完成! >> "%LOG_FILE%"

pause