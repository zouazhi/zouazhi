#!/bin/bash

# 检查是否以 root 权限运行（安装和更新需要 root 权限）
if [ "$(id -u)" != "0" ]; then
    echo "错误：此脚本需要以 root 权限运行，请使用 sudo 或切换到 root 用户"
    exit 1
fi

# 检查文件是否具有可执行权限并修复
check_and_fix_permissions() {
    local file="$1"
    local desc="$2"
    if [ -f "$file" ] && [ ! -x "$file" ]; then
        chmod +x "$file" && echo "✅ 已为 $desc 添加可执行权限"
    elif [ -f "$file" ]; then
        echo "✅ $desc 已具有可执行权限"
    fi
}

# 主循环
while true; do
    # 显示操作选项菜单
    echo "请选择操作："
    echo "1) 安装（完整安装openppp2和配置）"
    echo "2) 改完配置后的系统服务写入（跳过拉取和修改，直接配置服务）"
    echo "3) 更新（更新openppp2 二进制文件并配置服务）"
    echo "4) 重启（重启ppp.service）"
    echo "5) 停止（停止ppp.service）"
    echo "6) 查看运行状况（查看/opt/ppp/ppp.log）"
    echo "7) 配置环境变量（设置全局命令行别名，使输入 'ppp' 调用此脚本）"
    echo "8) 卸载 ppp（删除 /opt/ppp、停止并删除 ppp.service 并重载系统服务）"
    echo "9) 退出"
    read -p "请输入选项 (1/2/3/4/5/6/7/8/9)： " OPERATION

    case $OPERATION in
        1)
            # 安装模式
            # 更新软件源并安装 jq 和 uuidgen
            echo "正在更新软件源并安装 jq 和 uuidgen..."
            # 检测系统类型
            if command -v apt-get &> /dev/null; then
                # Ubuntu/Debian
                apt-get update
                apt-get install -y jq uuid-runtime
            elif command -v dnf &> /dev/null; then
                # CentOS 8+ / RHEL 8+ / Fedora
                dnf update -y
                dnf install -y jq util-linux
            elif command -v yum &> /dev/null; then
                # CentOS 7 / RHEL 7
                yum update -y
                yum install -y jq util-linux
            else
                echo "错误：无法识别包管理器，请手动安装 jq 和 uuidgen"
                continue
            fi

            # 验证 jq 是否安装成功
            if ! command -v jq &> /dev/null; then
                echo "错误：jq 安装失败，请检查包管理器或手动安装"
                continue
            fi
            echo "✅ jq 安装完成，版本：$(jq --version)"

            # 验证 uuidgen 是否安装成功
            if ! command -v uuidgen &> /dev/null; then
                echo "错误：uuidgen 安装失败，请检查包管理器或手动安装"
                continue
            fi
            echo "✅ uuidgen 安装完成"

            # 拉取并安装 openppp2 二进制文件
            mkdir -p /opt/ppp && cd /opt/ppp
            if [ -f "/opt/ppp/ppp" ]; then
                echo "检测到已存在 ppp 文件，将重新下载并覆盖"
            fi
            wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64.zip && \
            unzip -o $(ls | grep -m1 'openppp2.*\.zip') ppp -d . && \
            chmod +x ppp && \
            echo "✅ ppp 安装完成" && \
            rm -f $(ls | grep -m1 'openppp2.*\.zip')

            # 检查 ppp 可执行权限
            check_and_fix_permissions "/opt/ppp/ppp" "ppp 二进制文件"

            # 拉取启动脚本
            wget https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/ppp.sh && \
            chmod +x ppp.sh && \
            echo "✅ 启动脚本 ppp.sh 拉取完成"

            # 检查 ppp.sh 可执行权限
            check_and_fix_permissions "/opt/ppp/ppp.sh" "ppp.sh 启动脚本"

            # 询问是否自行修改配置文件
            echo "是否自行修改 appsettings.json 文件？"
            echo "1) 是（脚本将暂停，修改后重新运行脚本）"
            echo "2) 否（通过脚本输入 IP、端口和 GUID）"
            read -p "请输入选项 (1/2)： " CONFIG_OPTION
            if [ "$CONFIG_OPTION" = "1" ]; then
                echo "请手动修改 /opt/ppp/appsettings.json 文件，完成后重新运行脚本选择选项 2"
                continue
            elif [ "$CONFIG_OPTION" != "2" ]; then
                echo "错误：无效选项，返回菜单"
                continue
            fi

            # 拉取配置文件
            wget -O appsettings.json https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/appsettings.json && \
            echo "✅ 配置文件 appsettings.json 拉取完成"

            # 提示用户输入新的 IP、端口和 GUID
            echo "请配置 appsettings.json 文件："
            read -p "请输入新的 IP 地址（当前为 1.1.1.1，留空保留默认）： " NEW_IP
            read -p "请输入新的端口（当前为 20000，留空保留默认）： " NEW_PORT
            read -p "请输入新的 GUID（当前为 {guid}，留空生成随机 UUID）： " NEW_GUID

            # 设置默认值
            NEW_IP=${NEW_IP:-"1.1.1.1"}
            NEW_PORT=${NEW_PORT:-"20000"}

            # 如果未输入 GUID，生成随机 UUID
            if [ -z "$NEW_GUID" ]; then
                NEW_GUID=$(uuidgen)
                echo "✅ 已生成随机 UUID：$NEW_GUID"
            fi

            # 验证 IP 地址格式（简单 IPv4 验证）
            if ! [[ "$NEW_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                echo "错误：请输入有效的 IPv4 地址（格式：x.x.x.x）"
                continue
            fi

            # 验证端口（1-65535）
            if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_PORT" -lt 1 ] || [ "$NEW_PORT" -gt 65535 ]; then
                echo "错误：端口必须是 1-65535 的数字"
                continue
            fi

            # 验证 GUID（简单验证，确保非空且格式合理，匹配 UUID 或任意非空字符串）
            if [ -z "$NEW_GUID" ]; then
                echo "错误：GUID 不能为空"
                continue
            fi
            # 可选：严格验证 UUID 格式（标准 UUID 格式为 8-4-4-4-12 字符）
            if ! [[ "$NEW_GUID" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
                echo "警告：输入的 GUID 不是标准 UUID 格式（例如 550e8400-e29b-41d4-a716-446655440000），但将继续使用"
            fi

            # 备份配置文件
            cp appsettings.json appsettings.json.bak && echo "✅ 已备份配置文件为 appsettings.json.bak"

            # 使用 jq 修改 JSON 配置文件
            jq --arg ip "$NEW_IP" --arg port "$NEW_PORT" --arg guid "$NEW_GUID" '
              .tcp.listen.port = ($port | tonumber) |
              .udp.listen.port = ($port | tonumber) |
              .udp.static.servers[0] = ($ip + ":" + $port) |
              .client.server = ("ppp://" + $ip + ":" + $port) |
              .client.guid = $guid
            ' appsettings.json > temp.json && mv temp.json appsettings.json && \
            echo "✅ 已更新 appsettings.json 配置："
            jq '.tcp.listen.port, .udp.listen.port, .udp.static.servers[0], .client.server, .client.guid' appsettings.json
            ;;
        2)
            # 改完配置后的系统服务写入
            if [ ! -f "/opt/ppp/appsettings.json" ]; then
                echo "错误：/opt/ppp/appsettings.json 不存在，请先运行安装（选项 1）或手动准备配置文件"
                continue
            fi
            cd /opt/ppp
            # 检查 ppp 和 ppp.sh 可执行权限
            check_and_fix_permissions "/opt/ppp/ppp" "ppp 二进制文件"
            check_and_fix_permissions "/opt/ppp/ppp.sh" "ppp.sh 启动脚本"
            ;;
        3)
            # 更新模式
            mkdir -p /opt/ppp && cd /opt/ppp
            wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64.zip && \
            unzip -o $(ls | grep -m1 'openppp2.*\.zip') ppp -d . && \
            chmod +x ppp && \
            echo "✅ ppp 更新完成" && \
            rm -f $(ls | grep -m1 'openppp2.*\.zip')

            # 检查 ppp 可执行权限
            check_and_fix_permissions "/opt/ppp/ppp" "ppp 二进制文件"
            check_and_fix_permissions "/opt/ppp/ppp.sh" "ppp.sh 启动脚本"

            # 重启 ppp.service
            systemctl restart ppp.service && \
            echo "✅ ppp.service 已重启"

            # 检查 ppp.service 状态
            SERVICE_STATUS=$(systemctl status ppp.service | grep "Active:" | awk '{print $2 " " $3}')
            if [ "$SERVICE_STATUS" = "active (running)" ]; then
                echo "✅ 服务状态：运行"
            else
                echo "❌ 服务状态：失败"
                echo "详细状态信息："
                systemctl status ppp.service
            fi
            ;;
        4)
            # 重启 ppp.service
            systemctl daemon-reload && \
            systemctl restart ppp.service && \
            echo "✅ ppp.service 已重启"

            # 检查 ppp.service 状态
            SERVICE_STATUS=$(systemctl status ppp.service | grep "Active:" | awk '{print $2 " " $3}')
            if [ "$SERVICE_STATUS" = "active (running)" ]; then
                echo "✅ 服务状态：运行"
            else
                echo "❌ 服务状态：失败"
                echo "详细状态信息："
                systemctl status ppp.service
            fi
            ;;
        5)
            # 停止 ppp.service
            systemctl stop ppp.service && \
            echo "✅ ppp.service 已停止"
            ;;
        6)
            # 查看运行状况（ppp.log）
            if [ -f "/opt/ppp/ppp.log" ]; then
                echo "✅ /opt/ppp/ppp.log 内容："
                cat /opt/ppp/ppp.log
            else
                echo "错误：/opt/ppp/ppp.log 文件不存在"
            fi
            ;;
        7)
            # 配置环境变量（设置全局命令行别名，使输入 'ppp' 调用此脚本）
            SCRIPT_PATH="/root/ppp_install.sh"
            PROFILE_SCRIPT="/etc/profile.d/ppp.sh"

            # 检查脚本是否存在
            if [ ! -f "$SCRIPT_PATH" ]; then
                echo "错误：脚本文件 $SCRIPT_PATH 不存在。请确保脚本位于 /root 目录下。"
                continue
            fi
            check_and_fix_permissions "$SCRIPT_PATH" "ppp_install.sh 脚本"

            # 全局配置：写入 /etc/profile.d/ppp.sh
            if [ -f "$PROFILE_SCRIPT" ]; then
                echo "⚠️ $PROFILE_SCRIPT 已存在，将备份并覆盖"
                cp "$PROFILE_SCRIPT" "$PROFILE_SCRIPT.bak.$(date +%Y%m%d_%H%M%S)"
            fi
            echo "# ppp 别名：调用 /root/ppp_install.sh" > "$PROFILE_SCRIPT"
            echo "alias ppp='sudo bash /root/ppp_install.sh'" >> "$PROFILE_SCRIPT"
            chmod +x "$PROFILE_SCRIPT"
            echo "✅ 已添加全局别名到 $PROFILE_SCRIPT：alias ppp='sudo bash /root/ppp_install.sh'"

            # 立即加载别名到当前 shell 会话
            source "$PROFILE_SCRIPT"
            echo "✅ 已加载别名到当前会话，'ppp' 命令现在可用"

            echo "全局配置已完成！新终端将自动生效，当前终端已立即生效。"
            ;;
        8)
            # 卸载 ppp
            echo "正在卸载 ppp..."

            # 停止服务
            if systemctl is-active --quiet ppp.service; then
                systemctl stop ppp.service && echo "✅ 已停止 ppp.service"
            else
                echo "⚠️ ppp.service 未运行，无需停止"
            fi

            # 禁用服务
            if systemctl is-enabled --quiet ppp.service; then
                systemctl disable ppp.service && echo "✅ 已禁用 ppp.service"
            fi

            # 删除服务文件
            if [ -f /etc/systemd/system/ppp.service ]; then
                rm -f /etc/systemd/system/ppp.service && echo "✅ 已删除 ppp.service 文件"
            fi

            # 重载 systemd
            systemctl daemon-reload && echo "✅ 已重载 systemd 服务"

            # 删除 /opt/ppp 目录
            if [ -d "/opt/ppp" ]; then
                rm -rf /opt/ppp && echo "✅ 已删除 /opt/ppp 目录"
            else
                echo "⚠️ /opt/ppp 目录不存在，无需删除"
            fi

            # 清理环境变量
            PROFILE_SCRIPT="/etc/profile.d/ppp.sh"
            if [ -f "$PROFILE_SCRIPT" ]; then
                rm -f "$PROFILE_SCRIPT" && echo "✅ 已移除全局别名文件 $PROFILE_SCRIPT"
            fi

            echo "✅ ppp 卸载完成！请重新登录或运行 'source /etc/profile' 以更新环境变量。"
            exit 0
            ;;
        9)
            # 退出
            echo "✅ 退出脚本"
            exit 0
            ;;
        *)
            echo "错误：无效选项，退出"
            exit 1
            ;;
    esac

    # 写入系统服务（选项 1、2 需要）
    if [ "$OPERATION" = "1" ] || [ "$OPERATION" = "2" ]; then
        wget -P /etc/systemd/system https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/ppp.service && \
        chmod +x /opt/ppp/ppp && \
        systemctl daemon-reload && \
        systemctl enable ppp.service && \
        systemctl start ppp.service && \
        echo "✅ ppp.service 已配置并启动"

        # 检查 ppp.service 状态
        SERVICE_STATUS=$(systemctl status ppp.service | grep "Active:" | awk '{print $2 " " $3}')
        if [ "$SERVICE_STATUS" = "active (running)" ]; then
            echo "✅ 服务状态：运行"
        else
            echo "❌ 服务状态：失败"
            echo "详细状态信息："
            systemctl status ppp.service
        fi
    fi

    # 提示完成并返回菜单
    echo "✅ 当前操作完成！"
    echo
done
