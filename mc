cd /opt/

# 下载 NodeJS 运行时环境，如果你已经安装了 NodeJS，请忽略此步骤。
wget https://nodejs.org/dist/v20.11.0/node-v20.11.0-linux-x64.tar.xz
tar -xvf node-v20.11.0-linux-x64.tar.xz

# 添加 NodeJS 到系统环境变量
ln -s /opt/node-v20.11.0-linux-x64/bin/node /usr/bin/node
ln -s /opt/node-v20.11.0-linux-x64/bin/npm /usr/bin/npm

# 进入你的安装目录
mkdir /opt/mcsmanager/
cd /opt/mcsmanager/

# 下载 MCSManager（如果无法下载可以先科学上网下载再上传到服务器）
wget https://github.com/MCSManager/MCSManager/releases/latest/download/mcsmanager_linux_release.tar.gz

# 解压到安装目录
tar -zxf mcsmanager_linux_release.tar.gz

nano /etc/systemd/system/mcweb.service

[Unit]
Description=MCSManager-Web

[Service]
WorkingDirectory=/opt/mcsmanager
ExecStart=/opt/mcsmanager/start-web.sh
Restart=always
RestartSec=3
KillSignal=SIGINT
User=root

[Install]
WantedBy=multi-user.target

/etc/systemd/system/mcdaemon.service

[Unit]
Description=MCSManager-Daemon

[Service]
WorkingDirectory=/opt/mcsmanager
ExecStart=/opt/mcsmanager/start-daemon.sh
Restart=always
RestartSec=3
KillSignal=SIGINT
User=root

[Install]
WantedBy=multi-user.target

chmod +x /opt/mcsmanager/start-daemon.sh && systemctl enable mcdaemon.service && systemctl daemon-reload && sudo systemctl start mcdaemon.service && sudo systemctl status mcdaemon.service
chmod +x /opt/mcsmanager/start-web.sh && systemctl enable start-web.sh && systemctl daemon-reload && sudo systemctl start start-web.sh && sudo systemctl status start-web.sh
