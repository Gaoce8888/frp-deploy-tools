#!/bin/bash

# FRP服务端快速配置脚本
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
CONFIG_FILE="$FRP_DIR/conf/frps.ini"
BIND_PORT=7000
BIND_ADDR="0.0.0.0"
TOKEN="change-this-to-your-secure-token"
DASHBOARD_PORT=7500
DASHBOARD_USER="admin"
DASHBOARD_PASS="admin"
VHOST_HTTP_PORT=80
VHOST_HTTPS_PORT=443
MAX_POOL_COUNT=50
MAX_PORTS_PER_CLIENT=0  # 0表示无限制

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
FRP服务端快速配置脚本

用法: $0 [选项]

选项:
  -h, --help                    显示此帮助信息
  -p, --port PORT               指定FRP服务器绑定端口 (默认: $BIND_PORT)
  -a, --addr ADDR               指定绑定地址 (默认: $BIND_ADDR)
  -t, --token TOKEN             指定认证令牌 (默认: 随机生成)
  -c, --config FILE             指定配置文件路径 (默认: $CONFIG_FILE)
  --dashboard-port PORT         指定Dashboard端口 (默认: $DASHBOARD_PORT)
  --dashboard-user USER         指定Dashboard用户名 (默认: $DASHBOARD_USER)
  --dashboard-pass PASS         指定Dashboard密码 (默认: $DASHBOARD_PASS)
  --vhost-http-port PORT        指定HTTP虚拟主机端口 (默认: $VHOST_HTTP_PORT)
  --vhost-https-port PORT       指定HTTPS虚拟主机端口 (默认: $VHOST_HTTPS_PORT)
  --max-pool COUNT              指定每个代理的最大连接池数量 (默认: $MAX_POOL_COUNT)
  --max-ports NUM               指定每个客户端最大端口数 (默认: 无限制)
  --no-dashboard                禁用Dashboard
  --simple                      使用简单配置，适合个人使用
  --secure                      启用安全增强选项

示例:
  $0 -p 7000 -t your-secure-token                 # 基本配置
  $0 --simple                                    # 简单配置模式
  $0 --secure --dashboard-port 7500              # 安全配置
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

# 函数: 生成随机令牌
generate_random_token() {
  cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1
}

# 函数: 生成基本配置
generate_server_config() {
  # 如果未指定令牌并且没有使用默认值，则生成随机令牌
  if [ "$TOKEN" = "change-this-to-your-secure-token" ]; then
    TOKEN=$(generate_random_token)
    log "INFO" "已生成随机令牌: $TOKEN"
  fi

  # 创建基本配置
  cat > "$CONFIG_FILE" << EOF
[common]
bind_addr = $BIND_ADDR
bind_port = $BIND_PORT
token = $TOKEN
log_file = $FRP_DIR/logs/frps.log
log_level = info
log_max_days = 7
EOF

  # 添加仪表盘配置
  if [ "${ENABLE_DASHBOARD:-1}" -eq 1 ]; then
    cat >> "$CONFIG_FILE" << EOF

# 仪表盘配置
dashboard_addr = $BIND_ADDR
dashboard_port = $DASHBOARD_PORT
dashboard_user = $DASHBOARD_USER
dashboard_pwd = $DASHBOARD_PASS
EOF
  fi

  # 添加虚拟主机设置
  cat >> "$CONFIG_FILE" << EOF

# 虚拟主机设置
vhost_http_port = $VHOST_HTTP_PORT
vhost_https_port = $VHOST_HTTPS_PORT
EOF

  # 添加高级设置
  cat >> "$CONFIG_FILE" << EOF

# 连接池设置
max_pool_count = $MAX_POOL_COUNT
EOF

  if [ "$MAX_PORTS_PER_CLIENT" -gt 0 ]; then
    echo "max_ports_per_client = $MAX_PORTS_PER_CLIENT" >> "$CONFIG_FILE"
  fi

  # 添加安全设置
  if [ "${ENABLE_SECURE:-0}" -eq 1 ]; then
    cat >> "$CONFIG_FILE" << EOF

# 安全设置
authentication_timeout = 900
allow_ports = 1000-65535
tls_only = true
EOF
  fi

  # 添加简单模式设置
  if [ "${ENABLE_SIMPLE:-0}" -eq 1 ]; then
    cat >> "$CONFIG_FILE" << EOF

# 简单模式额外设置
subdomain_host = $HOSTNAME
use_compression = true
EOF
  fi

  # 添加注释说明
  cat >> "$CONFIG_FILE" << EOF

# 说明:
# bind_port: FRP服务端监听端口
# dashboard_port: Web管理界面端口
# vhost_http_port: HTTP协议访问端口
# vhost_https_port: HTTPS协议访问端口
# token: 认证令牌，确保与客户端配置相同
# max_pool_count: 每个代理的最大连接池数量

# 更多配置选项请参考: https://gofrp.org/docs/reference/server-configures/
EOF
}

# 函数: 检查FRP安装
check_frp_installation() {
  if [ ! -d "$FRP_DIR" ]; then
    log "ERROR" "FRP目录 $FRP_DIR 不存在。请先安装FRP"
    log "INFO" "你可以使用以下命令安装FRP:"
    log "INFO" "  ./deploy_frp.sh"
    exit 1
  fi

  if [ ! -f "$FRP_DIR/frps" ]; then
    log "ERROR" "FRP服务端二进制文件不存在。请先安装FRP"
    exit 1
  fi

  # 创建配置目录（如果不存在）
  mkdir -p "$(dirname "$CONFIG_FILE")" "$FRP_DIR/logs"
}

# 函数: 测试FRP配置
test_frp_config() {
  log "INFO" "测试FRP服务端配置..."
  
  if "$FRP_DIR/frps" -c "$CONFIG_FILE" verify; then
    log "SUCCESS" "配置验证通过"
    return 0
  else
    log "ERROR" "配置验证失败"
    return 1
  fi
}

# 函数: 启动FRP服务
start_frp_service() {
  log "INFO" "为FRP服务端创建systemd服务..."
  
  # 创建systemd服务文件
  sudo tee "/etc/systemd/system/frps.service" > /dev/null << EOF
[Unit]
Description=FRP Server Service
After=network.target

[Service]
Type=simple
User=$(whoami)
ExecStart=$FRP_DIR/frps -c $CONFIG_FILE
Restart=always
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

  log "INFO" "重新加载systemd服务..."
  sudo systemctl daemon-reload

  log "INFO" "启动FRP服务端服务..."
  sudo systemctl restart frps
  sudo systemctl enable frps

  log "SUCCESS" "FRP服务端服务已启动并设置为开机自启"
  log "INFO" "查看服务状态: sudo systemctl status frps"
  log "INFO" "查看日志: tail -f $FRP_DIR/logs/frps.log"
}

# 函数: 检查端口可用性
check_port_availability() {
  local port=$1
  local service=$2
  
  if command -v ss &> /dev/null; then
    if ss -tuln | grep -q ":$port "; then
      log "WARN" "端口 $port 已被占用，$service 可能无法正常工作"
      return 1
    fi
  elif command -v netstat &> /dev/null; then
    if netstat -tuln | grep -q ":$port "; then
      log "WARN" "端口 $port 已被占用，$service 可能无法正常工作"
      return 1
    fi
  else
    log "WARN" "无法检查端口占用情况，请确保端口 $port 未被占用"
  fi
  
  return 0
}

# 函数: 检查防火墙设置
check_firewall() {
  log "INFO" "检查防火墙设置..."
  
  local firewall_cmd_exists=0
  local ufw_exists=0
  
  if command -v firewall-cmd &> /dev/null; then
    firewall_cmd_exists=1
  fi
  
  if command -v ufw &> /dev/null; then
    ufw_exists=1
  fi
  
  if [ $firewall_cmd_exists -eq 1 ]; then
    log "INFO" "检测到firewalld，请确保以下端口已开放:"
    log "INFO" "  - $BIND_PORT/tcp (FRP服务端口)"
    if [ "${ENABLE_DASHBOARD:-1}" -eq 1 ]; then
      log "INFO" "  - $DASHBOARD_PORT/tcp (Dashboard端口)"
    fi
    log "INFO" "  - $VHOST_HTTP_PORT/tcp (HTTP端口)"
    log "INFO" "  - $VHOST_HTTPS_PORT/tcp (HTTPS端口)"
    log "INFO" "可以使用以下命令开放端口:"
    log "INFO" "  sudo firewall-cmd --permanent --add-port=$BIND_PORT/tcp"
    log "INFO" "  sudo firewall-cmd --reload"
  elif [ $ufw_exists -eq 1 ]; then
    log "INFO" "检测到ufw，请确保以下端口已开放:"
    log "INFO" "  - $BIND_PORT/tcp (FRP服务端口)"
    if [ "${ENABLE_DASHBOARD:-1}" -eq 1 ]; then
      log "INFO" "  - $DASHBOARD_PORT/tcp (Dashboard端口)"
    fi
    log "INFO" "  - $VHOST_HTTP_PORT/tcp (HTTP端口)"
    log "INFO" "  - $VHOST_HTTPS_PORT/tcp (HTTPS端口)"
    log "INFO" "可以使用以下命令开放端口:"
    log "INFO" "  sudo ufw allow $BIND_PORT/tcp"
  else
    log "INFO" "未检测到已知防火墙，请手动确保已开放必要端口"
  fi
}

# 解析命令行参数
parse_arguments() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help)
        show_help
        exit 0
        ;;
      -p|--port)
        BIND_PORT="$2"
        shift 2
        ;;
      -a|--addr)
        BIND_ADDR="$2"
        shift 2
        ;;
      -t|--token)
        TOKEN="$2"
        shift 2
        ;;
      -c|--config)
        CONFIG_FILE="$2"
        shift 2
        ;;
      --dashboard-port)
        DASHBOARD_PORT="$2"
        shift 2
        ;;
      --dashboard-user)
        DASHBOARD_USER="$2"
        shift 2
        ;;
      --dashboard-pass)
        DASHBOARD_PASS="$2"
        shift 2
        ;;
      --vhost-http-port)
        VHOST_HTTP_PORT="$2"
        shift 2
        ;;
      --vhost-https-port)
        VHOST_HTTPS_PORT="$2"
        shift 2
        ;;
      --max-pool)
        MAX_POOL_COUNT="$2"
        shift 2
        ;;
      --max-ports)
        MAX_PORTS_PER_CLIENT="$2"
        shift 2
        ;;
      --no-dashboard)
        ENABLE_DASHBOARD=0
        shift
        ;;
      --simple)
        ENABLE_SIMPLE=1
        shift
        ;;
      --secure)
        ENABLE_SECURE=1
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
  log "INFO" "========== FRP服务端配置开始 =========="
  
  # 解析命令行参数
  parse_arguments "$@"
  
  # 检查FRP安装
  check_frp_installation
  
  # 检查端口可用性
  check_port_availability "$BIND_PORT" "FRP服务端"
  if [ "${ENABLE_DASHBOARD:-1}" -eq 1 ]; then
    check_port_availability "$DASHBOARD_PORT" "Dashboard"
  fi
  check_port_availability "$VHOST_HTTP_PORT" "HTTP虚拟主机"
  check_port_availability "$VHOST_HTTPS_PORT" "HTTPS虚拟主机"
  
  # 备份现有配置
  backup_config
  
  # 生成配置
  generate_server_config
  
  # 测试配置
  if ! test_frp_config; then
    log "ERROR" "配置测试失败，请检查配置并重试"
    exit 1
  fi
  
  # 检查防火墙
  check_firewall
  
  # 询问是否启动服务
  read -p "是否要启动FRP服务端服务并设置开机自启? (y/n): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    start_frp_service
  else
    log "INFO" "跳过服务设置"
    log "INFO" "你可以手动启动FRP服务端: $FRP_DIR/frps -c $CONFIG_FILE"
  fi
  
  # 输出配置信息
  log "SUCCESS" "========== FRP服务端配置完成 =========="
  log "INFO" "配置文件路径: $CONFIG_FILE"
  log "INFO" "FRP服务端端口: $BIND_PORT"
  
  if [ "${ENABLE_DASHBOARD:-1}" -eq 1 ]; then
    log "INFO" "Dashboard地址: http://$BIND_ADDR:$DASHBOARD_PORT"
    log "INFO" "Dashboard用户名: $DASHBOARD_USER"
    log "INFO" "Dashboard密码: $DASHBOARD_PASS"
  fi
  
  log "INFO" "访问配置令牌: $TOKEN"
  log "INFO" "请牢记此令牌，客户端连接时需要使用"
}

# 执行主函数
main "$@"