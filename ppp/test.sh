#!/bin/bash

ppp_dir="/etc/ppp" # 定义ppp安装目录

# 检测操作系统
OS=""
if [ -f /etc/redhat-release ]; then
    OS="CentOS"
elif [ -f /etc/os-release ]; then
   . /etc/os-release
    OS=$ID
fi

# 安装依赖
function install_dependencies() {
    echo "检测到操作系统：$OS"
    case "$OS" in
        ubuntu | debian)
            echo "更新系统和安装依赖 (Debian/Ubuntu)..."
            apt update && apt install -y sudo screen unzip wget uuid-runtime jq
            ;;
        centos)
            echo "安装依赖 (CentOS)..."
            yum install -y sudo screen unzip wget jq
            ;;
        *)
            echo "不支持的操作系统"
            return 1
            ;;
    esac
}

# 获取版本、下载和解压文件
function get_version_and_download() {
    kernel_version=$(uname -r)
    arch=$(uname -m)
    echo "系统架构: $arch, 内核版本: $kernel_version"
    
    compare_kernel_version=$(echo -e "5.10\n$kernel_version" | sort -V | head -n1)
    can_use_io=$([[ "$compare_kernel_version" == "5.10" && "$kernel_version" != "5.10" ]] && echo true || echo false)

    read -p "是否使用默认下载地址？[Y/n]: " use_default
    use_default=$(echo "$use_default" | tr '[:upper:]' '[:lower:]')

    if [[ "$use_default" == "n" || "$use_default" == "no" ]]; then
        echo "请输入自定义的下载地址:"
        read download_url
    else
        latest_version=$(curl -s https://api.github.com/repos/rebecca554owen/toys/releases/latest | jq -r '.tag_name')
        echo "当前最新版本: $latest_version"

        read -p "请输入要下载的版本号（回车默认使用最新版本 $latest_version）： " version
        version=${version:-$latest_version}

        if [[ "$arch" == "x86_64" ]]; then
            assets=("openppp2-linux-amd64-io-uring.zip" "openppp2-linux-amd64.zip")
        elif [[ "$arch" == "aarch64" ]]; then
            assets=("openppp2-linux-aarch64-io-uring.zip" "openppp2-linux-aarch64.zip")
        else
            echo "不支持的架构: $arch"
            exit 1
        fi

        if [[ "$version" == "$latest_version" ]]; then
            release_info=$(curl -s https://api.github.com/repos/rebecca554owen/toys/releases/latest)
        else
            release_info=$(curl -s "https://api.github.com/repos/rebecca554owen/toys/releases/tags/$version")
        fi

        selected_asset=""
        for asset in "${assets[@]}"; do
            download_url=$(echo "$release_info" | jq -r --arg name "$asset" '.assets[] | select(.name == $name) | .browser_download_url')
            [[ -n "$download_url" && "$download_url" != "null" ]] && { selected_asset=$asset; break; }
        done

        if [[ "$selected_asset" == "${assets[0]}" && "$can_use_io" == true ]]; then
            echo "检测到当前内核版本支持 io_uring 特性（要求 5.10+）"
            read -p "是否要使用 io_uring 优化版本？[Y/n] " use_io
            use_io=$(echo "$use_io" | tr '[:upper:]' '[:lower:]')
            [[ "$use_io" == "n" || "$use_io" == "no" ]] && selected_asset="${assets[1]}"
        elif [[ "$can_use_io" == false ]]; then
            echo "当前内核版本不满足 io_uring 要求（需要 5.10+），自动选择标准版"
            selected_asset="${assets[1]}"
        fi

        [[ -z "$selected_asset" ]] && { echo "无法获取到构建文件的下载链接。"; exit 1; }
        echo "选择的构建文件: $selected_asset"
    fi

    echo "下载文件中..."
    wget "$download_url"
    echo "解压下载的文件..."
    unzip -o '*.zip' -x 'appsettings.json' && rm *.zip
    chmod +x ppp
}

# 配置系统服务
function configure_service() {
    local mode_choice=$1
    local exec_start
    local restart_policy

    if [[ "$mode_choice" == "2" ]]; then
        exec_start="/usr/bin/screen -DmS ppp $ppp_dir/ppp --mode=client --tun-flash=yes --tun-ssmt=4/mq --tun-host=no"
        restart_policy="no"
    else
        exec_start="/usr/bin/screen -DmS ppp $ppp_dir/ppp --mode=server --tun-flash"
        restart_policy="always"
    fi

    echo "配置系统服务..."
    cat > /etc/systemd/system/ppp.service << EOF
[Unit]
Description=PPP Service with Screen
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$ppp_dir
ExecStart=$exec_start
Restart=$restart_policy
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
}

# 安装PPP服务
function install_ppp() {
    install_dependencies || return 1

    echo "创建目录并进入..."
    mkdir -p $ppp_dir
    cd $ppp_dir

    get_version_and_download

    echo "请选择模式（默认为服务端）："
    echo "1) 服务端"
    echo "2) 客户端"
    read -p "输入选择 (1 或 2，默认为服务端): " mode_choice
    mode_choice=${mode_choice:-1}

    configure_service "$mode_choice"
    modify_config
    start_ppp
    echo "PPP服务已配置并启动。"
}

# 启动PPP服务
function start_ppp() {
    sudo systemctl enable ppp.service
    sudo systemctl daemon-reload
    sudo systemctl start ppp.service
    echo "PPP服务已启动。"
}

# 停止PPP服务
function stop_ppp() {
    sudo systemctl stop ppp.service
    echo "PPP服务已停止。"
}

# 重启PPP服务
function restart_ppp() {
    sudo systemctl daemon-reload
    sudo systemctl restart ppp.service
    echo "PPP服务已重启。"
}

# 卸载PPP服务
function uninstall_ppp() {
    sudo systemctl stop ppp.service
    sudo systemctl disable ppp.service
    sudo rm -f /etc/systemd/system/ppp.service
    sudo systemctl daemon-reload
    sudo systemctl reset-failed
    echo "删除安装文件..."
    sudo rm -rf $ppp_dir
    echo "PPP服务已完全卸载。"
}

# 查看PPP会话
function view_ppp_session() {
    echo "查看PPP会话..."
    screen -r ppp
    echo "提示：使用 'Ctrl+a d' 来detach会话而不是关闭它。"
}

# 查看当前配置
function view_config() {
    ppp_config="${ppp_dir}/appsettings.json"
    if [ ! -f "${ppp_config}" ]; then
        echo "配置文件不存在"
        return 1
    fi
    
    echo -e "\n当前配置文件内容："
    jq . "${ppp_config}"
}

# 编辑特定配置项
function edit_config_item() {
    ppp_config="${ppp_dir}/appsettings.json"
    if [ ! -f "${ppp_config}" ]; then
        echo "配置文件不存在"
        return 1
    fi
    
    view_config
    
    echo -e "\n可配置项："
    echo "1) 接口IP"
    echo "2) 公网IP"
    echo "3) 监听端口"
    echo "4) 并发数"
    echo "5) 客户端GUID"
    read -p "请选择要修改的配置项 (1-5): " choice
    
    case $choice in
        1)
            read -p "请输入新的接口IP: " new_value
            jq ".ip.interface = \"${new_value}\"" "${ppp_config}" > tmp.json && mv tmp.json "${ppp_config}"
            ;;
        2)
            read -p "请输入新的公网IP: " new_value
            jq ".ip.public = \"${new_value}\"" "${ppp_config}" > tmp.json && mv tmp.json "${ppp_config}"
            ;;
        3)
            read -p "请输入新的监听端口: " new_value
            jq ".tcp.listen.port = ${new_value} | .udp.listen.port = ${new_value}" "${ppp_config}" > tmp.json && mv tmp.json "${ppp_config}"
            ;;
        4)
            read -p "请输入新的并发数: " new_value
            jq ".ppp.max_concurrent = ${new_value}" "${ppp_config}" > tmp.json && mv tmp.json "${ppp_config}"
            ;;
        5)
            read -p "请输入新的客户端GUID: " new_value
            jq ".client.guid = \"${new_value}\"" "${ppp_config}" > tmp.json && mv tmp.json "${ppp_config}"
            ;;
        *)
            echo "无效选择"
            ;;
    esac
}

# 主菜单
function main_menu() {
    clear
    echo "==================== PPP 管理脚本 ===================="
    echo "1) 安装 PPP"
    echo "2) 启动 PPP 服务"
    echo "3) 停止 PPP 服务"
    echo "4) 重启 PPP 服务"
    echo "5) 卸载 PPP"
    echo "6) 查看当前会话"
    echo "7) 查看当前配置"
    echo "8) 修改配置项"
    echo "9) 退出"
    echo "======================================================="
    read -p "请选择操作: " choice
    
    case $choice in
        1) install_ppp ;;
        2) start_ppp ;;
        3) stop_ppp ;;
        4) restart_ppp ;;
        5) uninstall_ppp ;;
        6) view_ppp_session ;;
        7) view_config ;;
        8) edit_config_item ;;
        9) exit 0 ;;
        *) echo "无效选择" ;;
    esac
}

# 进入主菜单
main_menu
