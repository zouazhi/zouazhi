mkdir ppp ; cd ppp 

mkdir /opt/ppp && cd /opt/ppp
#amd64
 #内核≤5.10
wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64.zip && unzip -o openppp2*.zip 'ppp' && unzip -n openppp2*.zip -x 'ppp' && find . -type f -name '*openppp2*.zip*' -exec rm {} +

#配置文件
wget -O appsettings.json https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/appsettings.json

##修改配置文件  2222→ip 当然端口也可以改 20000→端口
nano appsettings.json

screen -S ppp #新建screen ppp
chmod +x ppp && ./ppp -m -s #PPP~启动！
