#!/bin/bash

# FRP一键安装脚本
# 版本: 1.0.0

set -e

echo "========== 开始FRP一键安装 =========="

# 创建临时目录
TMP_DIR="$(mktemp -d)"
cd "$TMP_DIR"

echo "下载FRP部署工具集..."

# 下载脚本
curl -s -O https://raw.githubusercontent.com/Gaoce8888/frp-deploy-tools/main/deploy_frp.sh
curl -s -O https://raw.githubusercontent.com/Gaoce8888/frp-deploy-tools/main/setup_frp_client.sh
curl -s -O https://raw.githubusercontent.com/Gaoce8888/frp-deploy-tools/main/setup_frp_server.sh

# 添加执行权限
chmod +x deploy_frp.sh setup_frp_client.sh setup_frp_server.sh

echo "开始安装FRP..."
./deploy_frp.sh

echo "========== FRP安装完成 =========="
echo "现在您可以配置FRP:"
echo "客户端配置: ./setup_frp_client.sh -s 服务器地址 -t 令牌"
echo "服务端配置: ./setup_frp_server.sh"
