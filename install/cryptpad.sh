#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: githubaff0
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/cryptpad/cryptpad.git cryptpad

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y git
msg_ok "Installed Dependencies"

msg_info "Setup Node.js Repository"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" >/etc/apt/sources.list.d/nodesource.
t
msg_ok "Setup Node.js Repository"

msg_info "Setup Node.js"
$STD apt-get update
$STD apt-get install -y nodejs
#$STD npm install -g yarn
msg_ok "Setup Node.js"

msg_info "Setup Cryptpad"
cd /opt
RELEASE=$(curl -s https://api.github.com/repos/cryptpad/cryptpad/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
wget -q "https://github.com/cryptpad/cryptpad/archive/refs/tags/${RELEASE}.zip"
unzip -q "${RELEASE}.zip"
mv "cryptpad-${RELEASE:1}" /opt/cryptpad
useradd -r cryptpad -s /sbin/nologin
chown -R cryptpad: /opt/cryptpad
cd /opt/cryptpad

msg_info "Setup NPM dependencies"
npm ci
npm run install:components

msg_info "Install OnlyOffice"
./install-onlyoffice.sh

msg_info "Configure Cryptpad"
sed -e 's|/home/cryptpad/cryptpad|/opt/cryptpad|g' docs/cryptpad.service > /etc/systemd/system/cryptpad.service

cp config/config.example.js config/config.js
cp /opt/cryptpad/customize.dist/application_config.js /opt/cryptpad/customize/application_config.js
sed -i -e "/return AppConfig/i\
AppConfig.loginSalt = '$(openssl rand -base64 20)';'\

" /opt/cryptpad/customize/application_config.js

cat <<EOF | crontab -u cryptpad -
0 0 * * * /usr/bin/node cryptpad/scripts/evict-inactive.js > /dev/null
0 0 * * 0 /usr/bin/node cryptpad/scripts/evict-archived.js > /dev/null
EOF

#node server




msg_info "Installing Kepubify"
mkdir -p /opt/kepubify
cd /opt/kepubify
curl -fsSLO https://github.com/pgaskin/kepubify/releases/latest/download/kepubify-linux-64bit &>/dev/null
chmod +x kepubify-linux-64bit
msg_ok "Installed Kepubify"

msg_info "Installing Calibre-Web"
mkdir -p /opt/calibre-web
$STD apt-get install -y calibre
$STD wget https://github.com/janeczku/calibre-web/raw/master/library/metadata.db -P /opt/calibre-web
$STD pip install calibreweb
$STD pip install jsonschema
msg_ok "Installed Calibre-Web"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/cps.service
[Unit]
Description=Calibre-Web Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/calibre-web
ExecStart=/usr/local/bin/cps
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now cps.service
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
