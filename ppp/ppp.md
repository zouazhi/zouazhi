一脚脚本

<pre class="language-markup">wget -O ppp.sh https://raw.githubusercontent.com/zouazhi/zouazhi/refs/heads/main/ppp/ppp.sh && bash ppp.sh<code></code></pre>

需要时执行 /root/ppp.sh 即可

<pre class="language-markup">mkdir /opt/ppp && cd /opt/ppp && wget https://github.com/liulilittle/openppp2/releases/latest/download/openppp2-linux-amd64.zip && unzip "openppp2"* ppp appsettings.json && rm "openppp2"* && wget -O appsettings.json https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/appsettings.json <code></code></pre>

修改appsettings.json 配置文件

<pre class="language-markup">wget -P /etc/systemd/system https://raw.githubusercontent.com/zouazhi/zouazhi/main/ppp/config/ppp.service && chmod +x /opt/ppp/ && chmod +x /opt/ppp/ppp && systemctl daemon-reload && systemctl enable ppp.service  && systemctl start ppp.service && systemctl status ppp.service<code></code></pre>
