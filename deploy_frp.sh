#!/bin/bash

# FRP部署脚本 - 支持断点续传、多源下载和自动恢复
# 作者: Cline
# 版本: 1.0.0

set -e

# 颜色定义
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m" # 重置颜色

# 配置变量
FRP_DIR="$HOME/frp"
TEMP_DIR="$FRP_DIR/temp"
LOG_FILE="$FRP_DIR/deploy.log"
LOCK_FILE="$FRP_DIR/deploy.lock"
FRP_VERSION="0.51.3"  # 最新稳定版本
ARCH="amd64"  # 可选: amd64, arm64, arm, mips, mips64
OS="linux"    # 可选: linux, windows, darwin
DOWNLOAD_RETRY=3
CLEAN_CACHE=0
FORCE_REDOWNLOAD=0
BACKUP_CONFIG=1

# 下载源配置 (主源和备用源)
PRIMARY_SOURCE="https://github.com/fatedier/frp/releases/download"
BACKUP_SOURCES=(
  "https://download.fastgit.org/fatedier/frp/releases/download"
  "https://mirror.ghproxy.com/https://github.com/fatedier/frp/releases/download"
  "https://objects.githubusercontent.com/github-production-release-asset-"
)

# 函数: 记录消息到日志文件和标准输出
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
  
  echo -e "[$level] $(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
  echo -e "${color}[$level]${NC} $message"
}

# 函数: 检查是否有其他实例在运行
check_lock() {
  if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE")
    if ps -p "$pid" > /dev/null; then
      log "ERROR" "另一个部署实例 (PID: $pid) 正在运行。如果确认没有运行，请删除 $LOCK_FILE"
      exit 1
    else
      log "WARN" "发现过期的锁文件，将删除它"
      rm -f "$LOCK_FILE"
    fi
  fi
  
  # 创建锁文件
  echo $$ > "$LOCK_FILE"
  trap 'rm -f "$LOCK_FILE"' EXIT
}

# 函数: 创建必要的目录
create_directories() {
  log "INFO" "创建必要目录"
  mkdir -p "$FRP_DIR" "$TEMP_DIR" "$FRP_DIR/logs" "$FRP_DIR/conf"
  chmod 755 "$FRP_DIR"
}

# 函数: 根据环境确定最佳的下载工具
detect_download_tool() {
  if command -v curl &> /dev/null; then
    echo "curl"
  elif command -v wget &> /dev/null; then
    echo "wget"
  else
    log "ERROR" "未找到下载工具 (curl 或 wget)。请安装其中一个。"
    log "INFO" "尝试安装 curl..."
    if command -v apt &> /dev/null; then
      sudo apt update && sudo apt install -y curl
      echo "curl"
    elif command -v yum &> /dev/null; then
      sudo yum install -y curl
      echo "curl"
    else
      log "ERROR" "无法自动安装下载工具。请手动安装 curl 或 wget。"
      exit 1
    fi
  fi
}

# 函数: 使用特定源下载FRP
download_frp() {
  local source=$1
  local filename="frp_${FRP_VERSION}_${OS}_${ARCH}.tar.gz"
  local download_url="${source}/v${FRP_VERSION}/${filename}"
  local target_file="${TEMP_DIR}/${filename}"
  local download_tool=$(detect_download_tool)
  local download_params=""
  
  # 检查部分下载的文件
  if [ -f "${target_file}.part" ] && [ $FORCE_REDOWNLOAD -eq 0 ]; then
    log "INFO" "发现部分下载的文件，将继续下载"
    if [ "$download_tool" = "curl" ]; then
      download_params="-C -"
    elif [ "$download_tool" = "wget" ]; then
      download_params="-c"
    fi
  elif [ -f "$target_file" ] && [ $FORCE_REDOWNLOAD -eq 0 ]; then
    log "INFO" "文件已存在，跳过下载: $target_file"
    return 0
  else
    # 强制重新下载
    rm -f "${target_file}" "${target_file}.part"
  fi
  
  log "INFO" "从 $source 下载 FRP v${FRP_VERSION}..."
  
  local temp_file="${target_file}.part"
  local cmd=""
  
  if [ "$download_tool" = "curl" ]; then
    cmd="curl -L $download_params --connect-timeout 30 --retry 5 -o \"$temp_file\" \"$download_url\""
  else
    cmd="wget $download_params --timeout=30 --tries=5 -O \"$temp_file\" \"$download_url\""
  fi
  
  # 执行下载
  if eval $cmd; then
    mv "$temp_file" "$target_file"
    log "SUCCESS" "下载完成: $target_file"
    return 0
  else
    log "ERROR" "从 $source 下载失败"
    return 1
  fi
}

# 函数: 使用所有配置的源尝试下载FRP
try_all_sources() {
  local try_count=0
  
  # 先尝试主要源
  if download_frp "$PRIMARY_SOURCE"; then
    return 0
  fi
  
  # 如果主要源失败，尝试备用源
  log "WARN" "主要源下载失败，尝试备用源"
  for source in "${BACKUP_SOURCES[@]}"; do
    try_count=$((try_count + 1))
    log "INFO" "尝试备用源 $try_count/${#BACKUP_SOURCES[@]}: $source"
    
    if download_frp "$source"; then
      return 0
    fi
    
    # 在备用源之间添加短暂延迟
    sleep 2
  done
  
  log "ERROR" "所有下载源都失败了"
  return 1
}

# 函数: 安装解压缩后的FRP
install_frp() {
  local filename="frp_${FRP_VERSION}_${OS}_${ARCH}.tar.gz"
  local target_file="${TEMP_DIR}/${filename}"
  local extracted_dir="${TEMP_DIR}/frp_${FRP_VERSION}_${OS}_${ARCH}"
  
  if [ ! -f "$target_file" ]; then
    log "ERROR" "找不到下载的文件: $target_file"
    return 1
  fi
  
  log "INFO" "解压 FRP 文件..."
  tar -xzf "$target_file" -C "$TEMP_DIR"
  
  if [ ! -d "$extracted_dir" ]; then
    log "ERROR" "解压后找不到目录: $extracted_dir"
    return 1
  fi
  
  # 备份现有配置
  if [ $BACKUP_CONFIG -eq 1 ] && [ -f "$FRP_DIR/conf/frpc.ini" ]; then
    local backup_file="$FRP_DIR/conf/frpc.ini.backup.$(date +%Y%m%d%H%M%S)"
    log "INFO" "备份现有配置到 $backup_file"
    cp "$FRP_DIR/conf/frpc.ini" "$backup_file"
  fi
  
  # 复制文件到目标目录
  log "INFO" "安装 FRP 到 $FRP_DIR"
  
  # 复制二进制文件
  cp "$extracted_dir/frpc" "$FRP_DIR/"
  cp "$extracted_dir/frps" "$FRP_DIR/"
  chmod +x "$FRP_DIR/frpc" "$FRP_DIR/frps"
  
  # 复制配置文件示例（如果目标尚不存在）
  for conf_file in "$extracted_dir"/*.ini; do
    basename=$(basename "$conf_file")
    if [ ! -f "$FRP_DIR/conf/$basename" ]; then
      cp "$conf_file" "$FRP_DIR/conf/"
    else
      log "INFO" "配置文件已存在，跳过覆盖: $basename"
    fi
  done
  
  log "SUCCESS" "FRP 安装完成！二进制文件位置: $FRP_DIR/frpc 和 $FRP_DIR/frps"
  
  # 可选：清理临时文件
  if [ $CLEAN_CACHE -eq 1 ]; then
    log "INFO" "清理临时文件"
    rm -rf "$extracted_dir" "$target_file"
  fi
  
  return 0
}

# 函数: 创建systemd服务文件
create_systemd_service() {
  local service_type=$1  # frpc 或 frps
  local service_name="${service_type}.service"
  local service_file="/etc/systemd/system/${service_name}"
  local config_file="$FRP_DIR/conf/${service_type}.ini"
  
  if [ ! -f "$config_file" ]; then
    log "ERROR" "找不到配置文件: $config_file"
    return 1
  fi
  
  log "INFO" "创建 ${service_name} 服务..."
  
  sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=${service_type} service
After=network.target

[Service]
Type=simple
User=$(whoami)
ExecStart=$FRP_DIR/${service_type} -c $config_file
Restart=always
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
  
  log "INFO" "重新加载 systemd 服务..."
  sudo systemctl daemon-reload
  
  log "SUCCESS" "${service_name} 服务创建完成"
  log "INFO" "你可以使用以下命令启动服务:"
  log "INFO" "  sudo systemctl start ${service_name}"
  log "INFO" "  sudo systemctl enable ${service_name}"
  
  return 0
}

# 函数: 检查环境依赖
check_dependencies() {
  log "INFO" "检查系统依赖..."
  
  local missing_deps=()
  
  # 检查必要依赖
  for cmd in tar grep sed; do
    if ! command -v $cmd &> /dev/null; then
      missing_deps+=("$cmd")
    fi
  done
  
  if [ ${#missing_deps[@]} -ne 0 ]; then
    log "WARN" "缺少依赖: ${missing_deps[*]}"
    log "INFO" "尝试安装缺少的依赖..."
    
    if command -v apt &> /dev/null; then
      sudo apt update && sudo apt install -y "${missing_deps[@]}"
    elif command -v yum &> /dev/null; then
      sudo yum install -y "${missing_deps[@]}"
    else
      log "ERROR" "无法自动安装依赖。请手动安装: ${missing_deps[*]}"
      return 1
    fi
  fi
  
  return 0
}

# 函数: 显示使用帮助
show_help() {
  cat << EOF
FRP部署脚本 - 支持断点续传、多源下载和自动恢复

用法: $0 [选项]

选项:
  -h, --help             显示此帮助信息
  -v, --version VERSION  指定FRP版本 (默认: $FRP_VERSION)
  -a, --arch ARCH        指定架构 (默认: $ARCH)
                         可选: amd64, arm64, arm, mips, mips64
  -o, --os OS            指定操作系统 (默认: $OS)
                         可选: linux, windows, darwin
  -c, --clean            下载完成后清理缓存
  -f, --force            强制重新下载，忽略现有文件
  -d, --dir DIR          指定安装目录 (默认: $FRP_DIR)
  --client               安装并配置frpc服务
  --server               安装并配置frps服务
  --no-backup            不备份现有配置文件

示例:
  $0                     使用默认设置安装FRP
  $0 -v 0.50.0 -a arm64  安装特定版本和架构的FRP
  $0 --client --clean    安装FRP客户端并清理缓存
  $0 --server -f         强制重新下载并安装FRP服务端
EOF
}

# 解析命令行参数
parse_arguments() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help)
        show_help
        exit 0
        ;;
      -v|--version)
        FRP_VERSION="$2"
        shift 2
        ;;
      -a|--arch)
        ARCH="$2"
        shift 2
        ;;
      -o|--os)
        OS="$2"
        shift 2
        ;;
      -c|--clean)
        CLEAN_CACHE=1
        shift
        ;;
      -f|--force)
        FORCE_REDOWNLOAD=1
        shift
        ;;
      -d|--dir)
        FRP_DIR="$2"
        TEMP_DIR="$FRP_DIR/temp"
        LOG_FILE="$FRP_DIR/deploy.log"
        LOCK_FILE="$FRP_DIR/deploy.lock"
        shift 2
        ;;
      --client)
        SETUP_CLIENT=1
        shift
        ;;
      --server)
        SETUP_SERVER=1
        shift
        ;;
      --no-backup)
        BACKUP_CONFIG=0
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
  # 解析命令行参数
  parse_arguments "$@"
  
  # 创建日志文件目录
  mkdir -p "$(dirname "$LOG_FILE")"
  touch "$LOG_FILE"
  
  log "INFO" "========== FRP部署开始 =========="
  log "INFO" "FRP版本: $FRP_VERSION, 架构: $ARCH, 系统: $OS"
  
  # 检查锁文件
  check_lock
  
  # 检查依赖
  check_dependencies || exit 1
  
  # 创建目录
  create_directories
  
  # 下载FRP
  log "INFO" "开始下载FRP..."
  if ! try_all_sources; then
    log "ERROR" "FRP下载失败，请检查网络连接或手动下载"
    exit 1
  fi
  
  # 安装FRP
  if ! install_frp; then
    log "ERROR" "FRP安装失败"
    exit 1
  fi
  
  # 配置服务
  if [ "${SETUP_CLIENT:-0}" -eq 1 ]; then
    create_systemd_service "frpc"
  fi
  
  if [ "${SETUP_SERVER:-0}" -eq 1 ]; then
    create_systemd_service "frps"
  fi
  
  log "SUCCESS" "========== FRP部署完成 =========="
  log "INFO" "FRP安装路径: $FRP_DIR"
  log "INFO" "配置文件路径: $FRP_DIR/conf/"
  log "INFO" "日志文件: $LOG_FILE"
  
  # 删除锁文件 (通过trap处理)
}

# 执行主函数
main "$@"
