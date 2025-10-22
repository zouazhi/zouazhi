
<pre class="language-markup">mkdir /opt/ppp && cd /opt/ppp && wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64.zip && unzip -o $(ls | grep -m1 'openppp2.*\.zip') ppp -d . && chmod +x ppp && echo "✅ ppp 安装/更新完成" && rm -f $(ls | grep -m1 'openppp2.*\.zip') <code></code></pre>

修改appsettings.json 配置文件

<pre class="language-markup"> wget -O appsettings.json https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/appsettings.json <code></code></pre>


<pre class="language-markup">wget -P /etc/systemd/system https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/ppp.service && chmod +x /opt/ppp/ && chmod +x /opt/ppp/ppp && systemctl daemon-reload && systemctl enable ppp.service  && systemctl start ppp.service && systemctl status ppp.service<code></code></pre>
