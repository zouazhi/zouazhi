uname -a
dpkg --list | grep linux-image

安装依赖，前置，防火墙
apt update -y && apt install sudo -y 
sudo apt install ufw screen unzip wget -y

配置防火墙
sudo ufw allow 22/tcp && 
sudo ufw allow 20000 && 
sudo ufw enable 

mkdir ppp && cd ppp 

带uring的要求内核大于5.10，内存256，其他用兼容版本，aarch为arm CPU
wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64-io-uring.zip && unzip openppp2-linux-amd64-io-uring.zip
wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64.zip && unzip openppp2-linux-amd64.zip
wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-aarch64-io-uring.zip && unzip openppp2-linux-aarch64-io-uring.zip
wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-aarch64.zip && unzip openppp2-linux-aarch64.zip


自己配置的文件
wget -O appsettings.json https://raw.githubusercontent.com/zouazhi/zouazhi/main/appsettings.json
wget -O ppp https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp
##修改配置文件

screen -S ppp
chmod +x ppp && ./ppp -m -s
