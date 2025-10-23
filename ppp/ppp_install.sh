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

# 调试：确认脚本开始执行
echo "✅ 脚本启动，进入主循环"

# 主循环
while true; do
    # 调试：确认菜单打印
    echo "✅ 开始打印菜单"
    echo "请选择操作："
    echo "1) 安装（完整安装openppp2和配置）"
    echo "2) 改完配置后的系统服务写入（跳过拉取和修改，直接配置服务）"
    echo "3) 更新（更新openppp2 二进制文件并配置服务）"
    echo "4) 重启（重启ppp.service）"
    echo "5) 停止（停止ppp.service）"
    echo "6) 查看运行状况（查看/opt/ppp/ppp.log）"
    echo "7) 卸载 ppp（删除 /opt/ppp、停止并删除 ppp.service 并重载系统服务）"
    echo "8) 退出"
    read -p "请输入选项 (1/2/3/4/5/6/7/8)： " OPERATION

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
            echo "正在卸载 ppp..."
            if systemctl is-active --quiet ppp.service; then
                systemctl stop ppp.service && echo "✅ 已停止 ppp.service"
            fi
            if systemctl is-enabled --quiet ppp.service; then
                systemctl disable ppp.service && echo "✅ 已禁用 ppp.service"
            fi
            rm -f /etc/systemd/system/ppp.service && echo "✅ 已删除 ppp.service 文件"
            systemctl daemon-reload && echo "✅ 已重载 systemd"
            rm -rf /opt/ppp && echo "✅ 已删除 /opt/ppp"
            echo "✅ 请手动删除脚本文件 /root/ppp_install.sh 以完成清理（命令：rm /root/ppp_install.sh）"
            echo "✅ ppp 卸载完成！"
            exit 0
            ;;
        8)
            echo "✅ 退出脚本"
            exit 0
            ;;
        *)
            echo "错误：无效选项"
            exit 1
            ;;
    esac

    echo "✅ 当前操作完成！"
    echo
done
