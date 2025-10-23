#!/bin/bash

# 检查是否以 root 权限运行（安装和更新需要 root 权限）
if [ "$(id -u)" != "0" ]; then
    echo "错误：此脚本需要以 root 权限运行，请使用 sudo 或切换到 root 用户"
    exit 1
fi

# 检查是否已存在 appsettings.json，若存在则跳到系统服务写入
if [ -f "/opt/ppp/appsettings.json" ]; then
    echo "检测到已存在 appsettings.json，跳过拉取和修改步骤，直接进入系统服务配置"
    cd /opt/ppp
else
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
        exit 1
    fi

    # 验证 jq 是否安装成功
    if ! command -v jq &> /dev/null; then
        echo "错误：jq 安装失败，请检查包管理器或手动安装"
        exit 1
    fi
    echo "✅ jq 安装完成，版本：$(jq --version)"

    # 验证 uuidgen 是否安装成功
    if ! command -v uuidgen &> /dev/null; then
        echo "错误：uuidgen 安装失败，请检查包管理器或手动安装"
        exit 1
    fi
    echo "✅ uuidgen 安装完成"

    # 检查是否已存在 ppp 文件，决定安装或更新
    mkdir -p /opt/ppp && cd /opt/ppp
    if [ -f "/opt/ppp/ppp" ]; then
        echo "检测到已存在 ppp 文件，请选择操作："
        echo "1) 安装（重新下载并覆盖）"
        echo "2) 更新（重新下载最新版本并覆盖）"
        echo "3) 跳过安装/更新"
        read -p "请输入选项 (1/2/3)： " PPP_OPTION
        case $PPP_OPTION in
            1|2)
                wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64.zip && \
                unzip -o $(ls | grep -m1 'openppp2.*\.zip') ppp -d . && \
                chmod +x ppp && \
                echo "✅ ppp ${PPP_OPTION == 1 && '安装' || '更新'}完成" && \
                rm -f $(ls | grep -m1 'openppp2.*\.zip')
                ;;
            3)
                echo "✅ 跳过 ppp 安装/更新"
                ;;
            *)
                echo "错误：无效选项，退出"
                exit 1
                ;;
        esac
    else
        wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64.zip && \
        unzip -o $(ls | grep -m1 'openppp2.*\.zip') ppp -d . && \
        chmod +x ppp && \
        echo "✅ ppp 安装完成" && \
        rm -f $(ls | grep -m1 'openppp2.*\.zip')
    fi

    # 拉取启动脚本
    wget https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/ppp.sh && \
    chmod +x ppp.sh && \
    echo "✅ 启动脚本 ppp.sh 拉取完成"

    # 询问是否自行修改配置文件
    echo "是否自行修改 appsettings.json 文件？"
    echo "1) 是（脚本将暂停，修改后重新运行脚本）"
    echo "2) 否（通过脚本输入 IP、端口和 GUID）"
    read -p "请输入选项 (1/2)： " CONFIG_OPTION
    if [ "$CONFIG_OPTION" = "1" ]; then
        echo "请手动修改 /opt/ppp/appsettings.json 文件，完成后重新运行此脚本"
        echo "提示：重新运行时，脚本将检测现有配置文件并跳过拉取和修改步骤"
        exit 0
    elif [ "$CONFIG_OPTION" != "2" ]; then
        echo "错误：无效选项，退出"
        exit 1
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
        exit 1
    fi

    # 验证端口（1-65535）
    if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_PORT" -lt 1 ] || [ "$NEW_PORT" -gt 65535 ]; then
        echo "错误：端口必须是 1-65535 的数字"
        exit 1
    fi

    # 验证 GUID（简单验证，确保非空且格式合理，匹配 UUID 或任意非空字符串）
    if [ -z "$NEW_GUID" ]; then
        echo "错误：GUID 不能为空"
        exit 1
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
fi

# 写入系统服务
wget -P /etc/systemd/system https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/ppp.service && \
chmod +x /opt/ppp/ && \
chmod +x /opt/ppp/ppp && \
systemctl daemon-reload && \
systemctl enable ppp.service && \
systemctl start ppp.service && \
echo "✅ ppp.service 已配置并启动"

# 检查 ppp.service 状态
SERVICE_STATUS=$(systemctl status ppp.service | grep "Active:" | awk '{print $2 " " $3}')
if [ "$SERVICE_STATUS" = "active (running)" ]; then
    echo "✅ 服务状态：超过"
else
    echo "❌ 服务状态：失败"
    echo "详细状态信息："
    systemctl status ppp.service
fi

# 提示完成
echo "✅ 所有步骤完成！"
