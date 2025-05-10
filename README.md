# FRP 一键部署与配置工具集

这是一套用于快速部署、配置和管理 FRP (Fast Reverse Proxy) 的工具集。FRP 是一个高性能的反向代理应用，可用于内网穿透、负载均衡、暴露内部服务等场景。

## 文件说明

本工具集包含以下文件：

- **deploy_frp.sh** - FRP核心部署脚本，支持断点续传、多源下载和自动恢复
- **setup_frp_client.sh** - FRP客户端快速配置脚本
- **setup_frp_server.sh** - FRP服务端配置脚本
- **install_frp_windows.bat** - Windows环境下的FRP安装批处理脚本
- **quick_install.sh** - Linux环境下的一键安装脚本
- **quick_install.ps1** - Windows环境下的一键安装PowerShell脚本
- **token_guide.md** - FRP服务端令牌配置详细指南
- **frp_web_ui/** - FRP服务端图形化配置界面（详见下方说明）

## 功能特点

- ✅ 自动创建FRP目录结构
- ✅ 断点续传下载支持（网络中断可继续）
- ✅ 多下载源自动切换（主源失败时尝试备用源）
- ✅ 自动生成配置文件与服务
- ✅ 支持Linux/Windows多平台
- ✅ 防重复安装与配置备份
- ✅ 详细的日志记录
- ✅ 系统服务自动创建（开机自启）
- ✅ 图形化配置界面（Web UI）

## 一键安装指令

### Linux一键安装（Bash）

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Gaoce8888/frp-deploy-tools/main/quick_install.sh)"
```

### Windows一键安装（PowerShell）

```powershell
PowerShell -Command "Invoke-Expression (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/Gaoce8888/frp-deploy-tools/main/quick_install.ps1')"
```

## 详细使用说明

请查看各脚本文件中的注释和帮助信息，或运行脚本时添加 `--help` 参数获取详细用法。

## FRP Web UI 图形化配置界面

我们提供了一个基于Web的图形化界面，用于简化FRP服务端的配置和管理。无需手动编辑配置文件，通过浏览器即可完成所有操作。

### 主要功能

- 💻 **直观的图形界面**：替代手动编辑配置文件
- 🔒 **安全令牌生成**：自动生成复杂安全的认证令牌
- 📊 **仪表盘设置**：轻松配置FRP管理仪表盘
- 🚀 **服务管理**：一键启动、停止、重启FRP服务
- 📝 **配置预览**：实时查看和复制生成的配置
- 📋 **操作日志**：记录所有操作和服务状态变化

### 使用方法

1. **下载Web UI**：从GitHub仓库下载`frp_web_ui`目录

2. **安装依赖**：确保已安装Node.js和npm

3. **启动服务**：
   - Linux环境：
     ```bash
     cd frp_web_ui
     chmod +x start_frp_web_ui.sh
     ./start_frp_web_ui.sh
     ```
   - Windows环境：
     ```
     cd frp_web_ui
     start_frp_web_ui.bat
     ```

4. **访问界面**：打开浏览器访问 http://localhost:3000

5. **配置和管理**：使用Web界面完成FRP配置、启动和监控

### 自定义选项

- **设置FRP安装路径**：
  ```bash
  # Linux
  export FRP_PATH=/path/to/frp
  # Windows
  set FRP_PATH=C:\path\to\frp
  ```

- **自定义端口**：
  ```bash
  # Linux
  ./start_frp_web_ui.sh 8080
  # Windows
  start_frp_web_ui.bat 8080
  ```

详细使用说明请参见`frp_web_ui/README.md`文件。