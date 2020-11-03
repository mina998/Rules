#!/bin/bash
apt update
apt install unzip wget curl

# 安装Caddy
wget https://github.com/caddyserver/caddy/releases/download/v2.2.1/caddy_2.2.1_linux_amd64.deb
dpkg -i caddy_2.2.1_linux_amd64.deb && rm caddy_2.2.1_linux_amd64.deb

cd /etc/caddy/
caddy stop && caddy start

cd

# 安装Trojan-go
wget https://github.com/p4gefau1t/trojan-go/releases/download/v0.8.2/trojan-go-linux-amd64.zip
unzip -d trojan trojan-go-linux-amd64.zip && rm trojan-go-linux-amd64.zip

cat > trojan/server.yaml <<EOF
run-type: server
local-addr: 0.0.0.0
local-port: 443
remote-addr: 127.0.0.1
remote-port: 80
password:
  - 463888
ssl:
  cert: /root/ssl/ca.crt
  key: /root/ssl/ca.key
  sni: test.com
mux:
  enabled: true
  concurrency: 8
  idle_timeout: 60
router:
  enabled: true
  block:
    - 'geoip:private'
  geoip: /root/trojan/geoip.dat
  geosite: /root/trojan/geosite.dat
websocket:
  enabled: true
  path: /video
  host: test.com

EOF

cat > /etc/systemd/system/trojan-go.service <<EOF
[Unit]
Description=Trojan-Go - An unidentifiable mechanism that helps you bypass GFW
Documentation=https://p4gefau1t.github.io/trojan-go/
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/root/trojan/trojan-go -config /root/trojan/server.yaml
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF


mkdir ssl && touch ca.crt ca.key
