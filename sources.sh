#!/bin/bash

# 设置网络优先使用 IPv4
sudo sed -i 's/^#precedence ::ffff:0:0\/96  100/precedence ::ffff:0:0\/96  1000/' /etc/gai.conf
echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4 > /dev/null

# 安装 wget 和 curl 工具
sudo apt update
sudo apt install -y wget curl

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

# 恢复网络配置
sudo sed -i 's/^precedence ::ffff:0:0\/96  1000/#precedence ::ffff:0:0\/96  100/' /etc/gai.conf
sudo rm /etc/apt/apt.conf.d/99force-ipv4

# 删除自身脚本
rm -- "$0"
    
