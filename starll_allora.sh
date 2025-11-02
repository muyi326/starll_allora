#!/bin/bash

# Allora Network 启动脚本 - 电脑重启后使用
set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_step() { echo -e "${BLUE}==>${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# 常量定义
PROJECT_DIR="allora-offchain-node"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ABS_PATH="$HOME/$PROJECT_DIR"

# 检查Docker是否运行
check_docker() {
    if ! docker info &> /dev/null; then
        log_info "启动Docker服务..."
        
        if [[ "$(uname -s)" == "Darwin" ]]; then
            open -a Docker
        elif [[ -f /etc/os-release ]] && grep -q "ubuntu" /etc/os-release; then
            sudo systemctl start docker
        fi
        
        # 等待Docker启动
        local waited=0
        while [ $waited -lt 30 ]; do
            if docker info &> /dev/null; then
                log_info "✅ Docker已就绪"
                return 0
            fi
            echo -n "."
            sleep 2
            waited=$((waited + 2))
        done
        echo ""
    else
        log_info "✅ Docker已运行"
    fi
}

# 启动项目
start_project() {
    log_step "启动 Allora Network..."
    
    # 检查项目目录
    if [ ! -d "$PROJECT_ABS_PATH" ]; then
        log_info "❌ 项目目录不存在: $PROJECT_ABS_PATH"
        log_info "请先运行部署脚本"
        exit 1
    fi
    
    # 检查是否已在运行
    if cd "$PROJECT_ABS_PATH" && docker compose ps | grep -q "Up"; then
        log_info "✅ 服务已在运行中"
        cd "$PROJECT_ABS_PATH" && docker compose ps
        return 0
    fi
    
    # 启动服务
    log_info "启动服务..."
    cd "$PROJECT_ABS_PATH" && docker compose up -d
    
    # 等待服务启动
    log_info "等待服务启动..."
    for i in {1..20}; do
        if cd "$PROJECT_ABS_PATH" && docker ps | grep -q "allora-offchain-node" && docker ps | grep -q "allora-inference-server"; then
            log_info "✅ 所有服务启动成功"
            break
        fi
        echo -n "."
        sleep 2
    done
    echo ""
    
    # 显示状态
    echo "=== 服务状态 ==="
    cd "$PROJECT_ABS_PATH" && docker compose ps
}

# 健康检查
quick_health_check() {
    log_step "快速健康检查..."
    
    log_info "检查推理服务..."
    if curl -s http://localhost:8000/health > /dev/null; then
        log_info "✅ 推理服务正常"
    else
        log_info "⚠️ 推理服务检查失败，可能还在启动中"
    fi
    
    log_info "检查Offchain节点..."
    if cd "$PROJECT_ABS_PATH" && docker compose logs offchain-node --tail=3 | grep -q "error"; then
        log_info "⚠️ 节点可能存在错误，请查看日志"
    else
        log_info "✅ Offchain节点运行中"
    fi
}

# 自动进入日志监控
start_log_monitoring() {
    log_step "启动日志监控..."
    
    echo ""
    log_warn "正在进入实时日志监控模式..."
    log_warn "按 Ctrl+C 退出日志监控"
    echo ""
    log_info "开始显示所有服务日志:"
    
    # 启动实时日志监控
    cd "$PROJECT_ABS_PATH" && docker compose logs -f
}

# 显示服务信息
show_service_info() {
    log_step "服务信息"
    echo ""
    echo "📍 访问地址:"
    echo "   - 推理API: http://localhost:8000/inference/ETH"
    echo "   - 健康检查: http://localhost:8000/health"
    echo ""
    echo "🔧 退出日志监控后，可以运行以下命令:"
    echo "   - 重新进入日志: cd $PROJECT_ABS_PATH && docker compose logs -f"
    echo "   - 停止服务: cd $PROJECT_ABS_PATH && docker compose down"
    echo "   - 重启服务: cd $PROJECT_ABS_PATH && docker compose restart"
    echo ""
}

# 主函数
main() {
    echo "================================================"
    echo "🚀 Allora Network 启动脚本"
    echo "================================================"
    
    check_docker
    start_project
    quick_health_check
    show_service_info
    start_log_monitoring
    
    # 当用户退出日志监控后显示提示
    echo ""
    log_info "已退出日志监控模式"
    show_service_info
}

# 脚本执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
