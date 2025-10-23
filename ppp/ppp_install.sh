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
            echo "正在更新软件源并安装 jq 和 uuidgen..."
            if command -v apt-get &> /dev/null; then
                apt-get update
                apt-get install -y jq uuid-runtime
            elif command -v dnf &> /dev/null; then
                dnf update -y
                dnf install -y jq util-linux
            elif command -v yum &> /dev/null; then
                yum update -y
                yum install -y jq util-linux
            else
                echo "错误：无法识别包管理器，请手动安装 jq 和 uuidgen"
                continue
            fi

            if ! command -v jq &> /dev/null; then
                echo "错误：jq 安装失败"
                continue
            fi
            echo "✅ jq 安装完成，版本：$(jq --version)"

            if ! command -v uuidgen &> /dev/null; then
                echo "错误：uuidgen 安装失败"
                continue
            fi
            echo "✅ uuidgen 安装完成"

            mkdir -p /opt/ppp && cd /opt/ppp
            if [ -f "/opt/ppp/ppp" ]; then
                echo "检测到已存在 ppp 文件，将重新下载并覆盖"
            fi
            wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64.zip && \
            unzip -o $(ls | grep -m1 'openppp2.*\.zip') ppp -d . && \
            chmod +x ppp && \
            echo "✅ ppp 安装完成" && \
            rm -f $(ls | grep -m1 'openppp2.*\.zip')

            check_and_fix_permissions "/opt/ppp/ppp" "ppp 二进制文件"

            wget https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/ppp.sh && \
            chmod +x ppp.sh && \
            echo "✅ 启动脚本 ppp.sh 拉取完成"

            check_and_fix_permissions "/opt/ppp/ppp.sh" "ppp.sh 启动脚本"

            echo "是否自行修改 appsettings.json 文件？"
            echo "1) 是（脚本将暂停）"
            echo "2) 否（通过脚本输入 IP、端口和 GUID）"
            read -p "请输入选项 (1/2)： " CONFIG_OPTION
            if [ "$CONFIG_OPTION" = "1" ]; then
                echo "请手动修改 /opt/ppp/appsettings.json 文件后重新运行"
                continue
            elif [ "$CONFIG_OPTION" != "2" ]; then
                echo "错误：无效选项"
                continue
            fi

            wget -O appsettings.json https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/appsettings.json && \
            echo "✅ 配置文件 appsettings.json 拉取完成"

            read -p "请输入新的 IP 地址（默认 1.1.1.1）： " NEW_IP
            read -p "请输入新的端口（默认 20000）： " NEW_PORT
            read -p "请输入新的 GUID（留空随机生成）： " NEW_GUID

            NEW_IP=${NEW_IP:-"1.1.1.1"}
            NEW_PORT=${NEW_PORT:-"20000"}

            if [ -z "$NEW_GUID" ]; then
                NEW_GUID=$(uuidgen)
                echo "✅ 已生成随机 UUID：$NEW_GUID"
            fi

            if ! [[ "$NEW_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                echo "错误：无效 IP"
                continue
            fi

            if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_PORT" -lt 1 ] || [ "$NEW_PORT" -gt 65535 ]; then
                echo "错误：端口无效"
                continue
            fi

            cp appsettings.json appsettings.json.bak && echo "✅ 已备份配置文件"

            jq --arg ip "$NEW_IP" --arg port "$NEW_PORT" --arg guid "$NEW_GUID" '
              .tcp.listen.port = ($port | tonumber) |
              .udp.listen.port = ($port | tonumber) |
              .udp.static.servers[0] = ($ip + ":" + $port) |
              .client.server = ("ppp://" + $ip + ":" + $port) |
              .client.guid = $guid
            ' appsettings.json > temp.json && mv temp.json appsettings.json && \
            echo "✅ 已更新配置"
            ;;
        2)
            if [ ! -f "/opt/ppp/appsettings.json" ]; then
                echo "错误：未找到配置文件"
                continue
            fi
            cd /opt/ppp
            check_and_fix_permissions "/opt/ppp/ppp" "ppp 二进制文件"
            check_and_fix_permissions "/opt/ppp/ppp.sh" "ppp.sh 启动脚本"
            ;;
        3)
            mkdir -p /opt/ppp && cd /opt/ppp
            wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64.zip && \
            unzip -o $(ls | grep -m1 'openppp2.*\.zip') ppp -d . && \
            chmod +x ppp && \
            echo "✅ ppp 更新完成" && \
            rm -f $(ls | grep -m1 'openppp2.*\.zip')

            check_and_fix_permissions "/opt/ppp/ppp" "ppp 二进制文件"
            check_and_fix_permissions "/opt/ppp/ppp.sh" "ppp.sh 启动脚本"

            systemctl restart ppp.service && echo "✅ ppp.service 已重启"
            ;;
        4)
            systemctl daemon-reload
            systemctl restart ppp.service && echo "✅ ppp.service 已重启"
            ;;
        5)
            systemctl stop ppp.service && echo "✅ ppp.service 已停止"
            ;;
        6)
            if [ -f "/opt/ppp/ppp.log" ]; then
                cat /opt/ppp/ppp.log
            else
                echo "错误：/opt/ppp/ppp.log 不存在"
            fi
            ;;
        7)
            SCRIPT_PATH="/root/ppp_install.sh"
            PROFILE_SCRIPT="/etc/profile.d/ppp.sh"

            if [ ! -f "$SCRIPT_PATH" ]; then
                echo "错误：脚本文件 $SCRIPT_PATH 不存在"
                continue
            fi
            check_and_fix_permissions "$SCRIPT_PATH" "ppp_install.sh 脚本"

            if [ -f "$PROFILE_SCRIPT" ]; then
                cp "$PROFILE_SCRIPT" "$PROFILE_SCRIPT.bak.$(date +%Y%m%d_%H%M%S)"
            fi

            echo "# ppp 别名：调用 /root/ppp_install.sh" > "$PROFILE_SCRIPT"
            echo "alias ppp='sudo bash /root/ppp_install.sh'" >> "$PROFILE_SCRIPT"
            chmod +x "$PROFILE_SCRIPT"
            echo "✅ 已添加全局别名到 $PROFILE_SCRIPT"

            # 立即加载别名到当前 shell 会话
            source "$PROFILE_SCRIPT"
            echo "✅ 已加载别名到当前会话，'ppp' 命令现在可用"

            # 自动添加到 root 的 .bashrc
            BASHRC="/root/.bashrc"
            if ! grep -q "source /etc/profile.d/ppp.sh" "$BASHRC"; then
                echo "source /etc/profile.d/ppp.sh" >> "$BASHRC"
                echo "✅ 已在 $BASHRC 中添加 source /etc/profile.d/ppp.sh"
            else
                echo "✅ $BASHRC 已包含 source /etc/profile.d/ppp.sh"
            fi

            echo "✅ 全局配置完成：'ppp' 命令现已在所有 Shell 中可用"
            ;;
        8)
            echo "正在卸载 ppp..."
            if systemctl is-active --quiet ppp.service; then
                systemctl stop ppp.service && echo "✅ 已停止 ppp.service"
            fi
            if systemctl is-enabled --quiet ppp.service; then
                systemctl disable ppp.service && echo "✅ 已禁用 ppp.service"
            fi
            rm -f /etc/systemd/system/ppp.service
            systemctl daemon-reload && echo "✅ 已重载 systemd"
            rm -rf /opt/ppp && echo "✅ 已删除 /opt/ppp"
            rm -f /etc/profile.d/ppp.sh && echo "✅ 已移除全局别名文件"
            sed -i '/source \/etc\/profile\.d\/ppp\.sh/d' /root/.bashrc && echo "✅ 已从 .bashrc 移除加载行"
            unalias ppp 2>/dev/null
            echo "✅ 卸载完成"
            ;;
        9)
            echo "✅ 退出脚本"
            exit 0
            ;;
        *)
            echo "错误：无效选项"
            exit 1
            ;;
    esac

    # 写入系统服务（选项 1、2）
    if [ "$OPERATION" = "1" ] || [ "$OPERATION" = "2" ]; then
        wget -P /etc/systemd/system https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/ppp.service && \
        chmod +x /opt/ppp/ppp && \
        systemctl daemon-reload && \
        systemctl enable ppp.service && \
        systemctl start ppp.service && \
        echo "✅ ppp.service 已配置并启动"

        SERVICE_STATUS=$(systemctl is-active ppp.service)
        if [ "$SERVICE_STATUS" = "active" ]; then
            echo "✅ 服务状态：运行中"
        else
            echo "❌ 服务状态：失败"
            systemctl status ppp.service
        fi
    fi

    echo "✅ 当前操作完成！"
    echo
done
