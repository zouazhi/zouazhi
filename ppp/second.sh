
mkdir ppp ; cd ppp 

安装ppp github地址 https://github.com/liulilittle/openppp2

#amd64
#内核≤5.10
wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64.zip && unzip -o openppp2*.zip 'ppp' && unzip -n openppp2*.zip -x 'ppp' && find . -type f -name '*openppp2*.zip*' -exec rm {} +

#配置文件
wget -O appsettings.json https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/appsettings.json

##修改配置文件  2222→ip 当然端口也可以改 20000→端口
nano appsettings.json

#配置服务
wget -P /etc/systemd/system https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/ppp.service

chmod +x /opt/ppp/ && chmod +x /opt/ppp/ppp && systemctl daemon-reload && systemctl enable ppp.service  && systemctl start ppp.service && systemctl status ppp.service



wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64.zip && unzip -o openppp2*.zip 'ppp' && unzip -n openppp2*.zip -x 'ppp' && find . -type f -name '*openppp2*.zip*' -exec rm {} + && wget -O appsettings.json https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/appsettings.json && nano appsettings.json


wget -P /etc/systemd/system https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/ppp.service && chmod +x /opt/ppp/ && chmod +x /opt/ppp/ppp && systemctl daemon-reload && systemctl enable ppp.service  && systemctl start ppp.service && systemctl status ppp.service


systemctl enable ppp.service
systemctl daemon-reload
sudo systemctl start ppp.service
sudo systemctl status ppp.service
sudo systemctl stop ppp.service
sudo systemctl restart ppp.service
systemctl disable ppp.service

