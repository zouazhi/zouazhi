#!/bin/bash
# =============================================================================
# openppp2 一键安装脚本（完整优化版 v2.0）
# 修复了 ppp.service 拉取失败问题 + 所有已知 Bug
# 作者：基于原脚本优化
# =============================================================================

set -o pipefail

# ==================== 颜色定义 ====================
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
RESET='\033[0m'

print() {
    echo -e "${2:-$GREEN}$1${RESET}"
}

# 检查 root 权限
if [ "$(id -u)" != "0" ]; then
    print "❌ 错误：此脚本必须以 root 权限运行！请使用 sudo bash $0" $RED
    exit 1
fi

# ==================== 函数 ====================
check_and_fix_permissions() {
    local file="$1"
    local desc="$2"
    if [ -f "$file" ]; then
        if [ ! -x "$file" ]; then
            chmod +x "$file" && print "✅ 已为 $desc 添加可执行权限" $GREEN
        else
            print "✅ $desc 已具有可执行权限" $GREEN
        fi
    fi
}

prompt_replace_file() {
    local target_path="$1"      # 完整目标路径
    local url="$2"
    local desc="$3"

    local target_dir=$(dirname "$target_path")
    mkdir -p "$target_dir"

    # 文件已存在时询问
    if [ -f "$target_path" ]; then
        print "⚠️  $desc 已存在 → $target_path" $YELLOW
        read -p "是否替换？(y/n，默认 n): " REPLACE
        if [[ ! "$REPLACE" =~ ^[Yy]$ ]]; then
            print "✅ 保留现有文件，跳过下载" $GREEN
            return 0
        fi
    fi

    print "📥 正在下载 $desc ..." $BLUE
    # 关键修复：直接 -O 到完整路径 + 显示进度 + 失败时打印详细错误
    if wget -4 --no-check-certificate -q --show-progress -O "$target_path" "$url"; then
        print "✅ $desc 下载完成" $GREEN
        return 0
    else
        print "❌ 下载 $desc 失败！" $RED
        print "🔍 详细错误信息：" $YELLOW
        wget -4 --no-check-certificate -O "$target_path" "$url" 2>&1 | tail -n 15
        return 1
    fi
}

# ==================== 主菜单循环 ====================
while true; do
    clear
    print "=============== openppp2 一键脚本（优化版）===============" $BLUE
    echo "1) 服务端 - 完整自动安装（推荐）"
    echo "2) 服务端 - 仅配置系统服务（已手动修改配置）"
    echo "3) 通用 - 更新二进制文件"
    echo "4) 通用 - 重启服务"
    echo "5) 通用 - 停止服务"
    echo "6) 通用 - 查看运行状态"
    echo "7) 通用 - 完全卸载"
    echo "8) 退出脚本"
    read -p "请输入选项 [1-8]: " OPERATION

    case $OPERATION in
        1)
            print "🔧 正在安装依赖（jq、uuidgen、unzip）..." $BLUE
            if command -v apt-get >/dev/null; then
                apt-get update -qq && apt-get install -y jq uuid-runtime unzip
            elif command -v dnf >/dev/null; then
                dnf install -y jq util-linux unzip
            elif command -v yum >/dev/null; then
                yum install -y jq util-linux unzip
            else
                print "❌ 无法识别包管理器，请手动安装 jq uuid-runtime unzip" $RED
                continue
            fi

            # 依赖检查
            for cmd in jq uuidgen unzip; do
                if ! command -v "$cmd" >/dev/null; then
                    print "❌ $cmd 安装失败，请手动安装后重试" $RED
                    continue 2
                fi
            done

            mkdir -p /opt/ppp && cd /opt/ppp

            # 下载并解压 openppp2 二进制（修复通配符问题）
            prompt_replace_file "/opt/ppp/openppp2.zip" \
                "https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64.zip" \
                "openppp2.zip" || continue

            unzip -o openppp2.zip ppp -d . && chmod +x ppp && rm -f openppp2.zip
            print "✅ openppp2 二进制文件安装完成" $GREEN

            check_and_fix_permissions "/opt/ppp/ppp" "ppp 主程序"

            # 下载启动脚本
            prompt_replace_file "/opt/ppp/ppp.sh" \
                "https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/ppp.sh" \
                "ppp.sh 启动脚本" || continue
            chmod +x ppp.sh
            check_and_fix_permissions "/opt/ppp/ppp.sh" "ppp.sh 启动脚本"

            # 配置 appsettings.json
            read -p "是否自行修改 appsettings.json？(y/n，默认 n): " SELF_CONFIG
            if [[ "$SELF_CONFIG" =~ ^[Yy]$ ]]; then
                print "✅ 请手动编辑 /opt/ppp/appsettings.json 后重新运行脚本" $YELLOW
                continue
            fi

            prompt_replace_file "/opt/ppp/appsettings.json" \
                "https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/appsettings.json" \
                "appsettings.json" || continue

            read -p "服务器 IP（默认 1.1.1.1）: " NEW_IP
            read -p "端口（默认 20000）: " NEW_PORT
            read -p "GUID（留空自动生成）: " NEW_GUID

            NEW_IP=${NEW_IP:-1.1.1.1}
            NEW_PORT=${NEW_PORT:-20000}
            [[ -z "$NEW_GUID" ]] && NEW_GUID=$(uuidgen) && print "✅ 已生成随机 GUID: $NEW_GUID" $GREEN

            # 随机密钥
            PROTOCOL_KEY=$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 16)
            TRANSPORT_KEY=$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 16)
            print "✅ 已生成随机 protocol-key: $PROTOCOL_KEY" $GREEN
            print "✅ 已生成随机 transport-key: $TRANSPORT_KEY" $GREEN

            cp -f appsettings.json appsettings.json.bak 2>/dev/null
            jq --indent 4 \
                --arg ip "$NEW_IP" \
                --arg port "$NEW_PORT" \
                --arg guid "$NEW_GUID" \
                --arg pkey "$PROTOCOL_KEY" \
                --arg tkey "$TRANSPORT_KEY" '
                .tcp.listen.port = ($port|tonumber) |
                .udp.listen.port = ($port|tonumber) |
                .udp.static.servers[0] = ($ip + ":" + $port) |
                .client.server = ("ppp://" + $ip + ":" + $port) |
                .client.guid = $guid |
                .key."protocol-key" = $pkey |
                .key."transport-key" = $tkey
            ' appsettings.json > temp.json && mv temp.json appsettings.json

            print "✅ appsettings.json 配置更新完成" $GREEN

            # 关键修复：ppp.service 下载
            prompt_replace_file "/etc/systemd/system/ppp.service" \
                "https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/ppp.service" \
                "ppp.service 系统服务" || continue

            chmod 644 /etc/systemd/system/ppp.service
            systemctl daemon-reload
            systemctl enable --now ppp.service

            if systemctl is-active --quiet ppp.service; then
                print "🎉 openppp2 服务端安装并启动成功！" $GREEN
            else
                print "⚠️ 服务启动失败，请运行选项 6 查看日志" $YELLOW
            fi
            ;;

        2)
            if [ ! -f "/opt/ppp/appsettings.json" ]; then
                print "❌ 未找到 /opt/ppp/appsettings.json，请先运行选项 1" $RED
                continue
            fi
            cd /opt/ppp || { print "❌ /opt/ppp 目录不存在" $RED; continue; }

            check_and_fix_permissions "/opt/ppp/ppp" "ppp 主程序"
            check_and_fix_permissions "/opt/ppp/ppp.sh" "ppp.sh 启动脚本"

            prompt_replace_file "/etc/systemd/system/ppp.service" \
                "https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/ppp.service" \
                "ppp.service 系统服务" || continue

            chmod 644 /etc/systemd/system/ppp.service
            systemctl daemon-reload
            systemctl enable --now ppp.service

            if systemctl is-active --quiet ppp.service; then
                print "✅ ppp.service 已启动" $GREEN
            else
                print "⚠️ 服务启动失败" $YELLOW
            fi
            ;;

        3)
            mkdir -p /opt/ppp && cd /opt/ppp
            prompt_replace_file "/opt/ppp/openppp2.zip" \
                "https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64.zip" \
                "openppp2.zip" || continue

            unzip -o openppp2.zip ppp -d . && chmod +x ppp && rm -f openppp2.zip
            print "✅ openppp2 二进制文件更新完成" $GREEN

            check_and_fix_permissions "/opt/ppp/ppp" "ppp 主程序"
            check_and_fix_permissions "/opt/ppp/ppp.sh" "ppp.sh 启动脚本"

            systemctl restart ppp.service && print "✅ ppp.service 已重启" $GREEN
            ;;

        4)
            systemctl daemon-reload
            systemctl restart ppp.service && print "✅ ppp.service 已重启" $GREEN
            ;;

        5)
            systemctl stop ppp.service && print "✅ ppp.service 已停止" $GREEN
            ;;

        6)
            print "=== ppp.log 日志 ===" $BLUE
            if [ -f "/opt/ppp/ppp.log" ]; then
                cat /opt/ppp/ppp.log | tail -n 50
            else
                print "ppp.log 不存在" $YELLOW
            fi
            echo
            print "=== ppp.service 状态 ===" $BLUE
            systemctl status ppp.service --no-pager -l
            ;;

        7)
            print "🗑️  开始卸载 openppp2 ..." $YELLOW
            if systemctl is-active --quiet ppp.service; then
                systemctl stop ppp.service && print "✅ 已停止服务" $GREEN
            fi
            if systemctl is-enabled --quiet ppp.service; then
                systemctl disable ppp.service && print "✅ 已禁用服务" $GREEN
            fi
            rm -f /etc/systemd/system/ppp.service && print "✅ 已删除 ppp.service" $GREEN
            systemctl daemon-reload
            rm -rf /opt/ppp && print "✅ 已删除 /opt/ppp 目录" $GREEN
            print "✅ 卸载完成！如需删除本脚本请手动执行：rm -f /root/ppp_install.sh" $GREEN
            exit 0
            ;;

        8)
            print "👋 退出脚本" $GREEN
            exit 0
            ;;

        *)
            print "❌ 无效选项，请输入 1-8" $RED
            ;;
    esac

    echo
    read -p "按 Enter 键返回主菜单..." 
done
