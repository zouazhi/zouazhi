#!/bin/bash
# ==========================================
# 通用 systemd 服务创建脚本
# 支持自定义 Description / WorkingDirectory / ExecStart / SyslogIdentifier
# 若同名文件已存在，会提示是否覆盖
# ==========================================

echo "=============================="
echo "   Linux systemd 服务创建工具"
echo "=============================="
echo ""

# 1️⃣ 服务名称
read -p "请输入服务名称（不带 .service）： " SERVICE_NAME
if [[ -z "$SERVICE_NAME" ]]; then
    echo "❌ 服务名称不能为空"
    exit 1
fi

SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# 检查是否存在
if [[ -f "$SERVICE_FILE" ]]; then
    echo "⚠️  服务文件已存在：$SERVICE_FILE"
    read -p "是否覆盖？(y/n)： " overwrite
    if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
        echo "🚫 已取消创建"
        exit 0
    fi
fi

# 2️⃣ 服务描述
read -p "请输入服务描述（Description）： " DESCRIPTION
DESCRIPTION=${DESCRIPTION:-"Custom Service"}

# 3️⃣ 工作目录
read -p "请输入工作目录（WorkingDirectory）： " WORK_DIR
WORK_DIR=${WORK_DIR:-"/"}

# 4️⃣ 启动命令
read -p "请输入启动命令（ExecStart）： " EXEC_START
if [[ -z "$EXEC_START" ]]; then
    echo "❌ 启动命令不能为空"
    exit 1
fi

# 5️⃣ 日志标识
read -p "请输入 SyslogIdentifier（默认同服务名）： " SYSLOG_ID
SYSLOG_ID=${SYSLOG_ID:-$SERVICE_NAME}

# 写入服务文件
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=${DESCRIPTION}
After=network.target

[Service]
Type=simple
WorkingDirectory=${WORK_DIR}
ExecStart=${EXEC_START}
Restart=always
RestartSec=3
SyslogIdentifier=${SYSLOG_ID}

[Install]
WantedBy=multi-user.target
EOF

# 重载 systemd
systemctl daemon-reload

echo ""
echo "✅ 服务已创建成功：$SERVICE_FILE"
echo ""
echo "可执行以下命令："
echo "-----------------------------------------"
echo "systemctl enable ${SERVICE_NAME}     # 开机自启"
echo "systemctl start ${SERVICE_NAME}      # 启动服务"
echo "systemctl status ${SERVICE_NAME}     # 查看状态"
echo "-----------------------------------------"
