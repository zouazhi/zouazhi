#检查内核
uname -a
or 
dpkg --list | grep linux-image

安装依赖，前置，防火墙
apt update -y && apt install sudo -y 
sudo apt install ufw screen unzip wget -y

配置防火墙
sudo ufw allow 22/tcp && sudo ufw allow 20000  #放行22 20000
sudo ufw enable   #开启ufw

mkdir ppp ; cd ppp 

#带uring的要求内核大于5.10，内存256，其他用兼容版本，aarch为arm CPU
#amd64
 #内核≥5.10 内存≥256MB
wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64-io-uring.zip && unzip openppp2*.zip && find . -type f -name '*openppp2*.zip*' -exec rm {} +
 #内核≤5.10
wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64.zip && unzip openppp2*.zip* && find . -type f -name '*openppp2*.zip*' -exec rm {} +

#arm-aarch
 #内核≥5.10 内存≥256MB
wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-aarch64-io-uring.zip && unzip openppp2*.zip && find . -type f -name '*openppp2*.zip*' -exec rm {} +
 #内核≤5.10
wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-aarch64.zip && unzip openppp2*.zip && find . -type f -name '*openppp2*.zip*' -exec rm {} +


#配置文件
wget -O appsettings.json https://raw.githubusercontent.com/zouazhi/zouazhi/main/appsettings.json

##修改配置文件  2222→ip 当然端口也可以改 20000→端口
nano appsettings.json

screen -S ppp #新建screen ppp
chmod +x ppp && ./ppp -m -s #PPP~启动！
