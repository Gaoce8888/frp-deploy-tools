# FRP服务端配置Web界面

这是一个用于配置和管理FRP服务端的Web界面，提供图形化操作替代手动编辑配置文件，使FRP的配置和管理更加简单直观。

## 功能特点

- 💻 **直观的图形界面**：替代手动编辑配置文件
- 🔒 **安全令牌生成**：自动生成复杂安全的认证令牌
- 📊 **仪表盘设置**：轻松配置FRP管理仪表盘
- 🚀 **服务管理**：一键启动、停止、重启FRP服务
- 📝 **配置预览**：实时查看和复制生成的配置
- 📋 **操作日志**：记录所有操作和服务状态变化
- 🔄 **自动同步**：配置更改自动应用到FRP服务

## 安装和使用

### 必要条件

- Node.js (v14.0.0或更高版本)
- npm (v6.0.0或更高版本)
- 已安装的FRP (v0.37.0或更高版本)

### 快速启动

1. 确保已安装FRP，并且位于`~/frp`目录下
   ```bash
   # 如果FRP在其他位置，请设置环境变量
   export FRP_PATH=/path/to/your/frp
   ```

2. 启动Web界面
   ```bash
   ./start_frp_web_ui.sh
   ```

3. 打开浏览器访问 http://localhost:3000

### 自定义端口

如需使用自定义端口启动服务：
```bash
./start_frp_web_ui.sh 8080  # 使用8080端口
```

## 界面说明

### 基本配置

- **绑定地址**：FRP服务端监听的IP地址，通常为`0.0.0.0`
- **绑定端口**：FRP服务端监听的端口，默认为`7000`
- **认证令牌**：客户端连接服务端的验证密钥
- **HTTP/HTTPS虚拟主机端口**：Web服务转发使用的端口

### 仪表盘配置

- **启用仪表盘**：开启/关闭FRP自带的管理仪表盘
- **仪表盘端口**：访问仪表盘的端口
- **用户名/密码**：仪表盘的访问凭证

### 高级配置

- **最大连接池**：服务端可以创建的连接池数量
- **每客户端最大端口数**：每个客户端最多可以使用的端口数
- **仅允许TLS连接**：提高安全性，只允许TLS加密连接
- **启用压缩**：对传输数据进行压缩
- **日志设置**：调整日志级别和保留时间

## 自动启动设置

### Linux (systemd)

创建系统服务实现开机自启：

1. 创建服务文件：
   ```bash
   sudo nano /etc/systemd/system/frp-web-ui.service
   ```

2. 添加以下内容：
   ```
   [Unit]
   Description=FRP Web UI
   After=network.target

   [Service]
   Type=simple
   User=你的用户名
   WorkingDirectory=/path/to/frp_web_ui
   ExecStart=/usr/bin/node server.js
   Restart=on-failure
   Environment=FRP_PATH=/path/to/frp

   [Install]
   WantedBy=multi-user.target
   ```

3. 启用并启动服务：
   ```bash
   sudo systemctl enable frp-web-ui
   sudo systemctl start frp-web-ui
   ```

## 故障排除

### 常见问题

1. **无法启动服务**
   - 检查Node.js和npm是否正确安装
   - 确认依赖项已安装：`npm install`
   - 检查端口是否被占用：`lsof -i :3000`

2. **FRP配置不生效**
   - 确认FRP_PATH环境变量设置正确
   - 检查FRP目录权限
   - 查看操作日志中的错误信息

3. **状态显示错误**
   - 检查FRP服务是否通过其他方式启动
   - 确认frps进程是否正在运行：`ps aux | grep frps`

## 许可证

MIT