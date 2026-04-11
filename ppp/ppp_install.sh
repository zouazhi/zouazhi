#!/bin/bash
# =============================================================================
# openppp2 一键安装脚本（v2.9）
# 默认加速 + 日志显示最后50行 + ppp快捷命令 + 彻底卸载
# =============================================================================

set -o pipefail

# ==================== 颜色定义 ====================
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
RESET='\033[0m'

print() { echo -e "${2:-$GREEN}$1${RESET}"; }

# ==================== 架构检测函数 ====================
detect_architecture() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)      echo "amd64" ;;
        aarch64|arm64)     echo "aarch64" ;;
        armv7l|armv7)      echo "armv7l" ;;
        mips|mipsel)       echo "mipsel" ;;
        ppc64le|ppc64el)   echo "ppc64el" ;;
        riscv64)           echo "riscv64" ;;
        s390x)             echo "s390x" ;;
        *)
            print "❌ 不支持的架构: $arch" $RED
            exit 1
            ;;
    esac
}

# ==================== 下载函数 ====================
prompt_replace_file() {
    local target_path="$1"
    local url="$2"
    local desc="$3"

    mkdir -p "$(dirname "$target_path")"

    if [ -f "$target_path" ]; then
        print "⚠️  $desc 已存在" $YELLOW
        read -p "是否替换？(y/n，默认 n): " REPLACE
        if [[ ! "$REPLACE" =~ ^[Yy]$ ]]; then return 0; fi
    fi

    print "📥 正在下载 $desc ..." $BLUE
    if wget -4 --no-check-certificate -q --show-progress -O "$target_path" "$url"; then
        print "✅ $desc 下载完成" $GREEN
        return 0
    else
        print "❌ 下载失败！" $RED
        return 1
    fi
}

# ==================== 主菜单 ====================
while true; do
    clear
    print "=============== openppp2 一键脚本（v2.9）===============" $BLUE
    echo "1) 服务端 - 完整自动安装（推荐）"
    echo "2) 服务端 - 配置系统服务（自行修改配置使用这个）"
    echo "3) 通用 - 更新二进制文件"
    echo "4) 通用 - 重启服务"
    echo "5) 通用 - 停止服务"
    echo "6) 通用 - 查看运行状态（日志最后50行）"
    echo "7) 通用 - 完全卸载"
    echo "8) 退出"
    read -p "请输入选项 [1-8]: " OPERATION

    case $OPERATION in
        1|2|3)
            print "🌍 是否使用国内加速代理 (git.apad.pro)？" $BLUE
            read -p "输入 y 使用加速，n 直连 (默认 y): " USE_PROXY
            if [[ "$USE_PROXY" =~ ^[Nn]$ ]]; then
                GITHUB_PROXY=""
                print "✅ 使用直连 GitHub" $YELLOW
            else
                GITHUB_PROXY="https://git.apad.pro/"
                print "✅ 已启用国内加速代理 (默认)" $GREEN
            fi

            if [ "$OPERATION" = "1" ] || [ "$OPERATION" = "3" ]; then
                ARCH=$(detect_architecture)
                print "🔍 检测到系统架构: $ARCH" $BLUE
            fi

            mkdir -p /opt/ppp && cd /opt/ppp

            if [ "$OPERATION" = "1" ] || [ "$OPERATION" = "3" ]; then
                ZIP_NAME="openppp2-linux-${ARCH}.zip"
                URL="${GITHUB_PROXY}https://github.com/liulilittle/openppp2/releases/latest/download/${ZIP_NAME}"
                prompt_replace_file "/opt/ppp/${ZIP_NAME}" "$URL" "openppp2-${ARCH}.zip" || continue

                unzip -o "$ZIP_NAME" ppp -d . && chmod +x ppp && rm -f "$ZIP_NAME"
                print "✅ openppp2 ($ARCH) 二进制处理完成" $GREEN
            fi

            if [ "$OPERATION" = "1" ]; then
                print "🔧 正在安装依赖（jq、uuid-runtime、unzip）..." $BLUE
                
                if command -v apt-get >/dev/null; then
                    apt-get update && apt-get install -y jq uuid-runtime unzip
                elif command -v dnf >/dev/null; then
                    dnf install -y jq util-linux unzip
                elif command -v yum >/dev/null; then
                    yum install -y jq util-linux unzip
                else
                    print "❌ 无法识别包管理器，请手动安装 jq uuid-runtime unzip" $RED
                    continue
                fi

                print "✅ 依赖安装完成" $GREEN

                prompt_replace_file "/opt/ppp/ppp.sh" "${GITHUB_PROXY}https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/ppp.sh" "ppp.sh" || continue
                chmod +x ppp.sh

                read -p "是否自行修改 appsettings.json？(y/n，默认 n): " SELF
                if [[ "$SELF" =~ ^[Yy]$ ]]; then
                    print "请手动修改 /opt/ppp/appsettings.json 后重新运行脚本并选择选项 2" $YELLOW
                    continue
                fi

                prompt_replace_file "/opt/ppp/appsettings.json" "${GITHUB_PROXY}https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/appsettings.json" "appsettings.json" || continue

                read -p "服务器 IP（默认 0.0.0.0）: " NEW_IP
                read -p "端口（默认 20000）: " NEW_PORT
                read -p "GUID（留空自动生成）: " NEW_GUID

                NEW_IP=${NEW_IP:-0.0.0.0}
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

                prompt_replace_file "/etc/systemd/system/ppp.service" "${GITHUB_PROXY}https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/ppp.service" "ppp.service" || continue

                chmod 644 /etc/systemd/system/ppp.service
                systemctl daemon-reload
                systemctl enable --now ppp.service

                systemctl is-active --quiet ppp.service && print "🎉 安装成功！服务已启动" $GREEN || print "⚠️ 服务启动失败，请检查日志" $YELLOW
            fi

            if [ "$OPERATION" = "2" ]; then
                prompt_replace_file "/etc/systemd/system/ppp.service" "${GITHUB_PROXY}https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/ppp.service" "ppp.service" || continue
                systemctl daemon-reload && systemctl enable --now ppp.service
                print "✅ 服务配置完成并启动" $GREEN
            fi

            if [ "$OPERATION" = "3" ]; then
                systemctl restart ppp.service && print "✅ 服务已重启" $GREEN
            fi
            ;;

        4) systemctl restart ppp.service && print "✅ 服务已重启" $GREEN ;;
        5) systemctl stop ppp.service && print "✅ 服务已停止" $GREEN ;;
        6)
            print "=== ppp.log（最后 50 行）===" $BLUE
            if [ -f "/opt/ppp/ppp.log" ]; then
                tail -n 50 /opt/ppp/ppp.log
            else
                print "日志文件不存在" $YELLOW
            fi
            echo
            print "=== ppp.service 状态 ===" $BLUE
            systemctl status ppp.service --no-pager -l
            ;;
        7)
            print "🗑️  开始彻底卸载..." $YELLOW
            systemctl stop ppp.service 2>/dev/null
            systemctl disable ppp.service 2>/dev/null
            rm -f /etc/systemd/system/ppp.service
            systemctl daemon-reload
            rm -rf /opt/ppp
            rm -f /root/ppp_install.sh
            print "✅ 已完全卸载（包括本脚本）" $GREEN
            exit 0
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
