#!/bin/bash

# 获取主机名
hostname=$(hostname)

# 获取 IPv4 地址
ipv4_address=$(ip -4 addr | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

# 更新 /etc/hosts 文件
if ! grep -q "$hostname" /etc/hosts; then
    echo "$ipv4_address $hostname" | sudo tee -a /etc/hosts > /dev/null
fi

# 备份原有的软件源文件
cp /etc/apt/sources.list /etc/apt/sources.list.bak

# 写入新的软件源配置
cat <<EOF > /etc/apt/sources.list
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirror-cdn.xtom.com/debian/ bookworm main contrib non-free non-free-firmware
deb-src https://mirror-cdn.xtom.com/debian/ bookworm main contrib non-free non-free-firmware

deb https://mirror-cdn.xtom.com/debian/ bookworm-updates main contrib non-free non-free-firmware
deb-src https://mirror-cdn.xtom.com/debian/ bookworm-updates main contrib non-free non-free-firmware

deb https://mirror-cdn.xtom.com/debian/ bookworm-backports main contrib non-free non-free-firmware
deb-src https://mirror-cdn.xtom.com/debian/ bookworm-backports main contrib non-free non-free-firmware

# deb https://mirror-cdn.xtom.com/debian-security bookworm-security main contrib non-free non-free-firmware
# deb-src https://mirror-cdn.xtom.com/debian-security bookworm-security main contrib non-free non-free-firmware

deb https://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb-src https://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
EOF

# 更新软件包索引
apt update

# 删除自身脚本
rm -- "$0"
    
