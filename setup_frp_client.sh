#!/bin/bash

# FRP客户端快速配置脚本
# 作者: Cline
# 版本: 1.0.0

set -e

# 颜色定义
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m" # 重置颜色

# 默认配置
FRP_DIR="$HOME/frp"
CONFIG_FILE="$FRP_DIR/conf/frpc.ini"
SERVER_ADDR="your-frp-server.com"
SERVER_PORT=7000
TOKEN="change-this-to-your-token"
LOCAL_PORT=22
REMOTE_PORT=0  # 0表示随机端口

# 函数: 记录消息
log() {
  local level=$1
  local message=$2
  local color=$NC
  
  case $level in
    "INFO") color=$BLUE ;;
    "SUCCESS") color=$GREEN ;;
    "WARN") color=$YELLOW ;;
    "ERROR") color=$RED ;;
  esac
  
  echo -e "${color}[$level]${NC} $message"
}

# 函数: 显示使用帮助
show_help() {
  cat << EOF
FRP客户端快速配置脚本

用法: $0 [选项]

选项:
  -h, --help               显示此帮助信息
  -s, --server SERVER      指定FRP服务器地址 (默认: $SERVER_ADDR)
  -p, --port PORT          指定FRP服务器端口 (默认: $SERVER_PORT)
  -t, --token TOKEN        指定认证令牌 (默认: $TOKEN)
  -l, --local-port PORT    指定本地端口 (默认: $LOCAL_PORT)
  -r, --remote-port PORT   指定远程端口 (默认: 随机)
  -n, --name NAME          指定隧道名称 (默认: ssh_隨机)
  -c, --config FILE        指定配置文件路径 (默认: $CONFIG_FILE)
  --http-port PORT         配置HTTP端口映射
  --https-port PORT        配置HTTPS端口映射
  --tcp                    使用TCP协议 (默认)
  --udp                    使用UDP协议
  --web-service            配置Web服务映射

示例:
  $0 -s frps.example.com -p 7000 -t your-token  # 基本SSH隧道
  $0 --http-port 80 --name web                 # Web服务器隧道
  $0 --tcp --local-port 3389 --name rdp        # RDP远程桌面隧道
EOF
}

# 函数: 备份现有配置
backup_config() {
  if [ -f "$CONFIG_FILE" ]; then
    local backup_file="${CONFIG_FILE}.backup.$(date +%Y%m%d%H%M%S)"
    log "INFO" "备份现有配置到 $backup_file"
    cp "$CONFIG_FILE" "$backup_file"
  fi
}

# 函数: 生成随机名称
generate_random_name() {
  echo "frpc_$(date +%s%N | md5sum | head -c 8)"
}

# 函数: 生成基本配置
generate_basic_config() {
  local tunnel_name="${TUNNEL_NAME:-ssh_$(date +%s%N | md5sum | head -c 8)}"
  
  cat > "$CONFIG_FILE" << EOF
[common]
server_addr = $SERVER_ADDR
server_port = $SERVER_PORT
token = $TOKEN
log_file = $FRP_DIR/logs/frpc.log
log_level = info
log_max_days = 3

[$tunnel_name]
type = ${PROTOCOL:-tcp}
local_ip = 127.0.0.1
local_port = $LOCAL_PORT
EOF

  # 添加远程端口配置（如果指定）
  if [ "$REMOTE_PORT" -ne 0 ]; then
    echo "remote_port = $REMOTE_PORT" >> "$CONFIG_FILE"
  fi

  # 添加HTTP/HTTPS配置（如果指定）
  if [ -n "$HTTP_PORT" ]; then
    cat >> "$CONFIG_FILE" << EOF

[web_http]
type = http
local_ip = 127.0.0.1
local_port = $HTTP_PORT
custom_domains = $SERVER_ADDR
EOF
  fi

  if [ -n "$HTTPS_PORT" ]; then
    cat >> "$CONFIG_FILE" << EOF

[web_https]
type = https
local_ip = 127.0.0.1
local_port = $HTTPS_PORT
custom_domains = $SERVER_ADDR
EOF
  fi

  # 添加Web服务配置（如果指定）
  if [ "${WEB_SERVICE:-0}" -eq 1 ]; then
    cat >> "$CONFIG_FILE" << EOF

[web]
type = http
local_ip = 127.0.0.1
local_port = ${HTTP_PORT:-80}
custom_domains = $SERVER_ADDR
EOF
  fi
}

# 函数: 检查FRP安装
check_frp_installation() {
  if [ ! -d "$FRP_DIR" ]; then
    log "ERROR" "FRP目录 $FRP_DIR 不存在。请先安装FRP"
    log "INFO" "你可以使用以下命令安装FRP:"
    log "INFO" "  ./deploy_frp.sh"
    exit 1
  fi

  if [ ! -f "$FRP_DIR/frpc" ]; then
    log "ERROR" "FRP客户端二进制文件不存在。请先安装FRP"
    exit 1
  fi

  # 创建配置目录（如果不存在）
  mkdir -p "$(dirname "$CONFIG_FILE")" "$FRP_DIR/logs"
}

# 函数: 测试FRP配置
test_frp_config() {
  log "INFO" "测试FRP配置..."
  
  if "$FRP_DIR/frpc" -c "$CONFIG_FILE" verify; then
    log "SUCCESS" "配置验证通过"
    return 0
  else
    log "ERROR" "配置验证失败"
    return 1
  fi
}

# 函数: 启动FRP服务
start_frp_service() {
  log "INFO" "为FRP创建systemd服务..."
  
  # 创建systemd服务文件
  sudo tee "/etc/systemd/system/frpc.service" > /dev/null << EOF
[Unit]
Description=FRP Client Service
After=network.target

[Service]
Type=simple
User=$(whoami)
ExecStart=$FRP_DIR/frpc -c $CONFIG_FILE
Restart=always
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

  log "INFO" "重新加载systemd服务..."
  sudo systemctl daemon-reload

  log "INFO" "启动FRP客户端服务..."
  sudo systemctl restart frpc
  sudo systemctl enable frpc

  log "SUCCESS" "FRP客户端服务已启动并设置为开机自启"
  log "INFO" "查看服务状态: sudo systemctl status frpc"
  log "INFO" "查看日志: tail -f $FRP_DIR/logs/frpc.log"
}

# 解析命令行参数
parse_arguments() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help)
        show_help
        exit 0
        ;;
      -s|--server)
        SERVER_ADDR="$2"
        shift 2
        ;;
      -p|--port)
        SERVER_PORT="$2"
        shift 2
        ;;
      -t|--token)
        TOKEN="$2"
        shift 2
        ;;
      -l|--local-port)
        LOCAL_PORT="$2"
        shift 2
        ;;
      -r|--remote-port)
        REMOTE_PORT="$2"
        shift 2
        ;;
      -n|--name)
        TUNNEL_NAME="$2"
        shift 2
        ;;
      -c|--config)
        CONFIG_FILE="$2"
        shift 2
        ;;
      --http-port)
        HTTP_PORT="$2"
        shift 2
        ;;
      --https-port)
        HTTPS_PORT="$2"
        shift 2
        ;;
      --tcp)
        PROTOCOL="tcp"
        shift
        ;;
      --udp)
        PROTOCOL="udp"
        shift
        ;;
      --web-service)
        WEB_SERVICE=1
        shift
        ;;
      *)
        log "ERROR" "未知参数: $1"
        show_help
        exit 1
        ;;
    esac
  done
}

# 主函数
main() {
  log "INFO" "========== FRP客户端配置开始 =========="
  
  # 解析命令行参数
  parse_arguments "$@"
  
  # 检查FRP安装
  check_frp_installation
  
  # 备份现有配置
  backup_config
  
  # 生成基本配置
  generate_basic_config
  
  # 测试配置
  if ! test_frp_config; then
    log "ERROR" "配置测试失败，请检查配置并重试"
    exit 1
  fi
  
  # 询问是否启动服务
  read -p "是否要启动FRP客户端服务并设置开机自启? (y/n): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    start_frp_service
  else
    log "INFO" "跳过服务设置"
    log "INFO" "你可以手动启动FRP客户端: $FRP_DIR/frpc -c $CONFIG_FILE"
  fi
  
  log "SUCCESS" "========== FRP客户端配置完成 =========="
  log "INFO" "配置文件路径: $CONFIG_FILE"
}

# 执行主函数
main "$@"