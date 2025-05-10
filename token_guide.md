# FRP服务端令牌配置指南

本指南介绍如何在安装FRP后配置服务端令牌，以及确保客户端与服务端之间的安全通信。

## 令牌的作用

FRP中的令牌(token)是客户端和服务端之间的共享密钥，用于验证连接请求的合法性。配置正确的令牌可以防止未授权的客户端连接到您的FRP服务器。

## 配置服务端令牌

### Linux环境

在Linux中，FRP安装完成后，您可以通过以下步骤配置服务端令牌：

#### 方法1：使用setup_frp_server.sh脚本（推荐）

```bash
# 使用-t或--token选项指定令牌
./setup_frp_server.sh -t "your-secure-token"

# 同时配置其他选项
./setup_frp_server.sh -t "your-secure-token" --dashboard-port 7500 --secure
```

#### 方法2：手动编辑配置文件

1. 打开服务端配置文件：
   ```bash
   nano ~/frp/conf/frps.ini
   ```

2. 修改token字段：
   ```ini
   [common]
   bind_addr = 0.0.0.0
   bind_port = 7000
   token = your-secure-token
   ```

3. 保存文件并重启FRP服务：
   ```bash
   sudo systemctl restart frps
   ```

### Windows环境

在Windows中，您可以通过以下步骤配置服务端令牌：

1. 打开服务端配置文件（通常位于`%USERPROFILE%\frp\conf\frps.ini`）
2. 使用记事本或其他文本编辑器编辑此文件
3. 修改token字段为您的安全令牌
4. 保存文件
5. 重新启动FRP服务

```ini
[common]
bind_addr = 0.0.0.0
bind_port = 7000
token = your-secure-token
```

## 令牌安全性建议

1. **使用复杂令牌**：令牌应该是随机生成的，包含数字、字母和特殊字符的组合
2. **定期更换**：建议每隔一段时间更换令牌
3. **妥善保管**：不要将令牌存储在公开的位置或共享给不相关的人员
4. **长度建议**：推荐使用至少16字符的令牌

## 查看和复制令牌

如果您使用`setup_frp_server.sh`脚本配置服务端，令牌将显示在配置完成后的输出中：

```
[SUCCESS] ========== FRP服务端配置完成 ==========
[INFO] 配置文件路径: /home/user/frp/conf/frps.ini
[INFO] FRP服务端端口: 7000
[INFO] Dashboard地址: http://0.0.0.0:7500
[INFO] Dashboard用户名: admin
[INFO] Dashboard密码: admin
[INFO] 访问配置令牌: your-secure-token
[INFO] 请牢记此令牌，客户端连接时需要使用
```

如果您想再次查看令牌，可以使用以下命令（Linux）：

```bash
grep "token" ~/frp/conf/frps.ini
```

## 客户端配置对应令牌

确保您的所有FRP客户端使用相同的令牌连接到服务端：

### Linux客户端

```bash
./setup_frp_client.sh -s your-server-address -t "your-secure-token"
```

### Windows客户端

编辑`%USERPROFILE%\frp\conf\frpc.ini`文件，确保token值与服务端一致：

```ini
[common]
server_addr = your-server-address
server_port = 7000
token = your-secure-token
```

## 故障排除

如果客户端无法连接到服务端，首先检查令牌是否匹配。常见的错误消息包括：

```
login to server failed: authentication failed
```

这通常表示客户端和服务端的令牌不匹配。