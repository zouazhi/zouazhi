#!/bin/bash
# =============================================================================
# openppp2 一键安装脚本（v2.2 智能加速版）
# 支持用户自行选择是否使用国内加速代理
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

# ==================== 用户选择加速代理 ====================
print "=============== openppp2 一键脚本 ===============" $BLUE
print "检测到您可能处于国内网络环境" $YELLOW
echo
print "是否使用国内 GitHub 加速代理？（git.apad.pro）" $BLUE
echo "1) 是（推荐国内服务器使用，速度更快）"
echo "2) 否（直连 GitHub，国外服务器或网络良好的情况）"
read -p "请输入 [1/2]（默认 1）: " USE_PROXY

if [ "$USE_PROXY" = "2" ]; then
    GITHUB_PROXY=""
    print "✅ 已选择直连 GitHub" $GREEN
else
    GITHUB_PROXY="https://git.apad.pro/"
    print "✅ 已启用国内加速代理" $GREEN
fi
echo

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
    local target_path="$1"
    local url="$2"
    local desc="$3"

    local target_dir=$(dirname "$target_path")
    mkdir -p "$target_dir"

    if [ -f "$target_path" ]; then
        print "⚠️  $desc 已存在" $YELLOW
        read -p "是否替换？(y/n，默认 n): " REPLACE
        if [[ ! "$REPLACE" =~ ^[Yy]$ ]]; then
            print "✅ 保留现有文件" $GREEN
            return 0
        fi
    fi

    print "📥 正在下载 $desc ..." $BLUE
    if wget -4 --no-check-certificate -q --show-progress -O "$target_path" "$url"; then
        print "✅ $desc 下载完成" $GREEN
        return 0
    else
        print "❌ 下载失败！" $RED
        print "🔍 错误信息：" $YELLOW
        wget -4 --no-check-certificate -O "$target_path" "$url" 2>&1 | tail -n 10
        return 1
    fi
}

# ==================== 主菜单 ====================
while true; do
    clear
    print "=============== openppp2 一键脚本（${GITHUB_PROXY:+加速版}${GITHUB_PROXY:-直连版}）===============" $BLUE
    echo "1) 服务端 - 完整自动安装（推荐）"
    echo "2) 服务端 - 仅配置系统服务"
    echo "3) 通用 - 更新二进制文件"
    echo "4) 通用 - 重启服务"
    echo "5) 通用 - 停止服务"
    echo "6) 通用 - 查看运行状态"
    echo "7) 通用 - 完全卸载"
    echo "8) 退出"
    read -p "请输入选项 [1-8]: " OPERATION

    case $OPERATION in
        1)
            print "🔧 正在安装依赖..." $BLUE
            if command -v apt-get >/dev/null; then
                apt-get update -qq && apt-get install -y jq uuid-runtime unzip
            elif command -v dnf >/dev/null; then
                dnf install -y jq util-linux unzip
            elif command -v yum >/dev/null; then
                yum install -y jq util-linux unzip
            else
                print "❌ 请手动安装 jq、uuid-runtime、unzip" $RED
                continue
            fi

            mkdir -p /opt/ppp && cd /opt/ppp

            prompt_replace_file "/opt/ppp/openppp2.zip" \
                "${GITHUB_PROXY}https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64.zip" \
                "openppp2.zip" || continue

            unzip -o openppp2.zip ppp -d . && chmod +x ppp && rm -f openppp2.zip

            check_and_fix_permissions "/opt/ppp/ppp" "ppp 主程序"

            prompt_replace_file "/opt/ppp/ppp.sh" \
                "${GITHUB_PROXY}https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/ppp.sh" \
                "ppp.sh" || continue
            chmod +x ppp.sh

            read -p "是否自行修改 appsettings.json？(y/n，默认 n): " SELF_CONFIG
            if [[ "$SELF_CONFIG" =~ ^[Yy]$ ]]; then
                print "请手动修改 /opt/ppp/appsettings.json 后重新运行" $YELLOW
                continue
            fi

            prompt_replace_file "/opt/ppp/appsettings.json" \
                "${GITHUB_PROXY}https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/appsettings.json" \
                "appsettings.json" || continue

            read -p "服务器 IP（默认 1.1.1.1）: " NEW_IP
            read -p "端口（默认 20000）: " NEW_PORT
            read -p "GUID（留空自动生成）: " NEW_GUID

            NEW_IP=${NEW_IP:-1.1.1.1}
            NEW_PORT=${NEW_PORT:-20000}
            [[ -z "$NEW_GUID" ]] && NEW_GUID=$(uuidgen)

            PROTOCOL_KEY=$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 16)
            TRANSPORT_KEY=$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 16)

            cp -f appsettings.json appsettings.json.bak 2>/dev/null

            jq --indent 4 \
                --arg ip "$NEW_IP" --arg port "$NEW_PORT" --arg guid "$NEW_GUID" \
                --arg pkey "$PROTOCOL_KEY" --arg tkey "$TRANSPORT_KEY" '
                .tcp.listen.port = ($port|tonumber) |
                .udp.listen.port = ($port|tonumber) |
                .udp.static.servers[0] = ($ip + ":" + $port) |
                .client.server = ("ppp://" + $ip + ":" + $port) |
                .client.guid = $guid |
                .key."protocol-key" = $pkey |
                .key."transport-key" = $tkey
            ' appsettings.json > temp.json && mv temp.json appsettings.json

            prompt_replace_file "/etc/systemd/system/ppp.service" \
                "${GITHUB_PROXY}https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/ppp.service" \
                "ppp.service" || continue

            chmod 644 /etc/systemd/system/ppp.service
            systemctl daemon-reload
            systemctl enable --now ppp.service

            if systemctl is-active --quiet ppp.service; then
                print "🎉 安装并启动成功！" $GREEN
            else
                print "⚠️ 服务启动失败，请使用选项 6 查看日志" $YELLOW
            fi
            ;;

        2)
            cd /opt/ppp 2>/dev/null || { print "❌ 未找到 /opt/ppp 目录" $RED; continue; }
            prompt_replace_file "/etc/systemd/system/ppp.service" \
                "${GITHUB_PROXY}https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/ppp.service" \
                "ppp.service" || continue
            systemctl daemon-reload && systemctl enable --now ppp.service
            print "✅ 服务配置完成" $GREEN
            ;;

        3)
            cd /opt/ppp 2>/dev/null || { print "❌ /opt/ppp 目录不存在" $RED; continue; }
            prompt_replace_file "/opt/ppp/openppp2.zip" \
                "${GITHUB_PROXY}https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64.zip" \
                "openppp2.zip" || continue
            unzip -o openppp2.zip ppp -d . && chmod +x ppp && rm -f openppp2.zip
            systemctl restart ppp.service && print "✅ 更新完成并重启" $GREEN
            ;;

        4)
            systemctl restart ppp.service && print "✅ 服务已重启" $GREEN
            ;;

        5)
            systemctl stop ppp.service && print "✅ 服务已停止" $GREEN
            ;;

        6)
            print "=== ppp.log 最后50行 ===" $BLUE
            [ -f "/opt/ppp/ppp.log" ] && tail -n 50 /opt/ppp/ppp.log || print "日志文件不存在" $YELLOW
            echo
            systemctl status ppp.service --no-pager -l
            ;;

        7)
            systemctl stop ppp.service 2>/dev/null
            systemctl disable ppp.service 2>/dev/null
            rm -f /etc/systemd/system/ppp.service
            systemctl daemon-reload
            rm -rf /opt/ppp
            print "✅ openppp2 已完全卸载" $GREEN
            ;;

        8)
            print "👋 退出脚本" $GREEN
            exit 0
            ;;

        *)
            print "❌ 无效选项" $RED
            ;;
    esac

    echo
    read -p "按 Enter 键返回主菜单..."
done
