#!/bin/sh

# 安装Socat
if [ ! -x /usr/bin/socat ] ; then 
	apt install socat
fi
# 安装并执行证书签发程序
curl https://get.acme.sh | sh
# 设置权限
source ~/.bashrc

read -p "请输入域名(ss.demo.com):" domain

localh_ip=$(curl https://api-ipv4.ip.sb/ip)
domain_ip=$(ping "${domain}" -c 1 | sed '1{s/[^(]*(//;s/).*//;q}')

echo "域名dns解析IP：${domain_ip}"

if [ $localh_ip == $domain_ip ] ; then
	echo "域名解析成功!"
else
	echo "域名解析失败.是否继续安装(y|N)" && read -r install
	case $install in
		[yY][eE][sS] | [yY])
            sleep 2
			;;
		*)
			echo "安装终止"
            exit 2
			;;	
	esac
fi

echo "开始申请证书."
acme.sh --issue -d "${domain}" --standalone -k ec-256 --force
#
mkdir ~/ssl
# 安装证书
acme.sh --installcert -d "${domain}" --fullchainpath ~/ssl/ca.crt --keypath ~/ssl/ca.key --ecc --force

# 下载trojan-gfw
wget https://github.com/trojan-gfw/trojan/releases/download/v1.16.0/trojan-1.16.0-linux-amd64.tar.xz
# 解压缩
tar vxf trojan-1.16.0-linux-amd64.tar.xz  && rm trojan-1.16.0-linux-amd64.tar.xz
# 删除多余文件
cd trojan && rm CONTRIBUTORS.md LICENSE README.md

read -p "请输入密码:" password
# 添加trojan配置文件
cat > config.json <<EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "${password}"
    ],
    "log_level": 1,
    "ssl": {
        "cert": "/root/ssl/ca.crt",
        "key": "/root/ssl/ca.key",
        "key_password": "",
        "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384",
        "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
        "prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "alpn_port_override": {
            "h2": 81
        },
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "prefer_ipv4": false,
        "no_delay": true,
        "keep_alive": true,
        "reuse_port": false,
        "fast_open": false,
        "fast_open_qlen": 20
    }
}
EOF

# 安装trojan服务
cat > /etc/systemd/system/trojan.service <<EOF
[Unit]
Description=trojan
Documentation=man:trojan(1) https://trojan-gfw.github.io/trojan/config https://trojan-gfw.github.io/trojan/
After=network.target network-online.target nss-lookup.target
[Service]
Type=simple
StandardError=journal
User=root
AmbientCapabilities=CAP_NET_BIND_SERVICE
ExecStart=/root/trojan/trojan -c /root/trojan/config.json
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=1s
[Install]
WantedBy=multi-user.target
EOF

systemctl start trojan
systemctl enable trojan

# 下载Caddy
wget https://github.com/caddyserver/caddy/releases/download/v2.2.1/caddy_2.2.1_linux_amd64.deb
# 安装Caddy
dpkg -i caddy_2.2.1_linux_amd64.deb && rm caddy_2.2.1_linux_amd64.deb


read -p "请输入伪装网站(https://www.qb5.tw):" web2

# 添加Caddy配置文件
cd /etc/caddy/ && cat > Caddyfile <<EOF
:80
reverse_proxy ${web2} {
    header_up Host {http.reverse_proxy.upstream.hostport}
}
EOF
# 重启Caddy
caddy stop && caddy start && cd ~

echo 服务器地址: $domain
echo 端口: 443
echo 密码: $password
echo 传输层加密: tls

systemctl status trojan
