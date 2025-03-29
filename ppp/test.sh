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

# 新增函数：检查命令是否成功
check_command() {
    if [ $? -ne 0 ]; then
        echo "错误: $1 执行失败"
        exit 1
    fi
}

# 安装依赖
function install_dependencies() {
    echo "检测到操作系统：$OS"
    
    case "$OS" in
        ubuntu | debian)
            echo "更新系统和安装依赖 (Debian/Ubuntu)..."
            apt update && apt install -y sudo screen unzip wget uuid-runtime jq
            check_command "安装依赖"
            ;;
        *)
            echo "不支持的操作系统"
            return 1
            ;;
    esac
}

# 获取版本、下载和解压文件
function get_version_and_download() {
    # 获取系统信息
    kernel_version=$(uname -r)
    arch=$(uname -m)
    echo "系统架构: $arch, 内核版本: $kernel_version"

    # 判断内核版本是否满足使用 io-uring 的条件
    compare_kernel_version=$(echo -e "5.10\n$kernel_version" | sort -V | head -n1)
    can_use_io=$([[ "$compare_kernel_version" == "5.10" && "$kernel_version" != "5.10" ]] && echo true || echo false)

    read -p "是否使用默认下载地址？[Y/n]: " use_default
    use_default=$(echo "$use_default" | tr '[:upper:]' '[:lower:]')

    if [[ "$use_default" == "n" || "$use_default" == "no" ]]; then
        echo "请输入自定义的下载地址:"
        read download_url
    else
        latest_version=$(curl -s https://api.github.com/repos/rebecca554owen/toys/releases/latest | jq -r '.tag_name')
        check_command "获取最新版本"
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

        [[ -z "$release_info" ]] && { echo "获取版本 $version 的发布信息失败，请检查版本号是否正确。"; exit 1; }

        # 选择下载文件
        selected_asset=""
        for asset in "${assets[@]}"; do
            download_url=$(echo "$release_info" | jq -r --arg name "$asset" '.assets[] | select(.name == $name) | .browser_download_url')
            [[ -n "$download_url" && "$download_url" != "null" ]] && { selected_asset=$asset; break; }
        done

        # 内核版本检查与版本选择（selected_asset 可能在此处被修改）
        if [[ "$selected_asset" == "${assets[0]}" && "$can_use_io" == true ]]; then
            echo "检测到当前内核版本支持 io_uring 特性（要求 5.10+）"
            read -p "是否要使用 io_uring 优化版本？[Y/n] " use_io
            use_io=$(echo "$use_io" | tr '[:upper:]' '[:lower:]')
            [[ "$use_io" == "n" || "$use_io" == "no" ]] && selected_asset="${assets[1]}"
        elif [[ "$can_use_io" == false ]]; then
            echo "当前内核版本不满足 io_uring 要求（需要 5.10+），自动选择标准版本"
            selected_asset="${assets[1]}"  # 强制使用标准版
        fi

        [[ -z "$selected_asset" ]] && { echo "无法获取到构建文件的下载链接。"; exit 1; }
        echo "选择的构建文件: $selected_asset"
    fi

    # 下载并解压文件
    download_and_unzip "$download_url"
}

# 下载并解压函数
download_and_unzip() {
    wget "$1" || { echo "下载失败！"; exit 1; }
    unzip -o '*.zip' -x 'appsettings.json' && rm *.zip || { echo "解压失败！"; exit 1; }
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
    show_menu
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

# 修改PPP配置文件
function modify_config() {
    ppp_config="${ppp_dir}/appsettings.json"
    
    # 备份原配置文件
    if [ -f "${ppp_config}" ]; then
        backup_file="${ppp_config}.$(date +%Y%m%d%H%M%S).bak"
        cp "${ppp_config}" "${backup_file}"
        echo "已备份原配置文件到 ${backup_file}"
    fi

    # 下载默认配置文件
    if [ ! -f "${ppp_config}" ]; then
        echo "下载配置文件..."
        if ! wget -q -O "${ppp_config}" "https://raw.githubusercontent.com/zouazhi/zouazhi/refs/heads/main/ppp/appsettings.json"; then
            echo "下载配置文件失败，请检查网络连接"
            return 1
        fi
    fi

    # 获取并显示当前配置
    display_current_config

    # 配置输入
    read_config_input

    # 更新配置
    update_config

    echo "配置文件更新完成。"
    restart_ppp
}

# 显示当前配置
function display_current_config() {
    echo -e "\n当前配置文件内容："
    jq . "${ppp_config}"
}

# 配置输入
function read_config_input() {
    default_public_ip="::"
    read -p "请输入VPS IP地址（服务端默认为${default_public_ip}，客户端则写vps的IP地址）: " public_ip
    public_ip=${public_ip:-$default_public_ip}

    while true; do
        read -p "请输入VPS 端口 [默认: 2020]： " ppp_port
        ppp_port=${ppp_port:-2020}

        if [[ ! "$ppp_port" =~ ^[0-9]{1,5}$ || "$ppp_port" -lt 1 || "$ppp_port" -gt 65535 ]]; then
            echo "请输入有效的端口号（1-65535）。"
        else
            break
        fi
    done
}

# 更新配置
function update_config() {
    # 更新配置项
    update_config_value ".PublicIP" "$public_ip"
    update_config_value ".PPPPort" "$ppp_port"
}

# 修改配置文件时的统一函数
function update_config_value() {
    local key=$1
    local value=$2
    jq "$key = \"$value\"" "${ppp_config}" > tmp.json && mv tmp.json "${ppp_config}"
    check_command "更新配置项 $key"
}

# 菜单
function show_menu() {
    echo "请选择操作："
    echo "1) 安装PPP服务"
    echo "2) 启动PPP服务"
    echo "3) 停止PPP服务"
    echo "4) 重启PPP服务"
    echo "5) 退出"
    read -p "请输入选项 (1-5): " menu_choice
    case $menu_choice in
        1) install_ppp ;;
        2) start_ppp ;;
        3) stop_ppp ;;
        4) restart_ppp ;;
        5) exit 0 ;;
        *) echo "无效选项，请重新选择。" ; show_menu ;;
    esac
}

# 启动菜单
show_menu
