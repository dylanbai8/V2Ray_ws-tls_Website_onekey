#!/bin/bash
# Usage:
#   curl https://raw.githubusercontent.com/linhua55/lkl_study/master/get-rinetd.sh | bash

# export RINET_URL="https://github.com/linhua55/lkl_study/releases/download/v1.2/rinetd_bbr_powered"
export RINET_URL="https://drive.google.com/uc?id=0B0D0hDHteoksVzZ4MG5hRkhqYlk"

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: Please run as root"
    exit 1
fi

for CMD in curl iptables grep cut xargs systemctl ip awk
do
	if ! type -p ${CMD}; then
		echo -e "\e[1;31mtool ${CMD} is not installed, abort.\e[0m"
		exit 1
	fi
done

echo -e "1. Clean up rinetd-bbr"
systemctl disable rinetd-bbr.service
killall -9 rinetd-bbr
rm -rf /usr/bin/rinetd-bbr  /etc/rinetd-bbr.conf /etc/systemd/system/rinetd-bbr.service

echo "2. Download rinetd-bbr from $RINET_URL"
curl -L "${RINET_URL}" >/usr/bin/rinetd-bbr
chmod +x /usr/bin/rinetd-bbr

echo "3. Generate /etc/rinetd-bbr.conf"
read -p "Input ports you want to speed up: " PORTS </dev/tty
for d in $PORTS
do          
cat <<EOF >> /etc/rinetd-bbr.conf
0.0.0.0 $d 0.0.0.0 $d 
EOF
done 

IFACE=$(ip -4 addr | awk '{if ($1 ~ /inet/ && $NF ~ /^[ve]/) {a=$NF}} END{print a}')

echo "4. Generate /etc/systemd/system/rinetd-bbr.service"
cat <<EOF > /etc/systemd/system/rinetd-bbr.service
[Unit]
Description=rinetd with bbr
Documentation=https://github.com/linhua55/lkl_study

[Service]
ExecStart=/usr/bin/rinetd-bbr -f -c /etc/rinetd-bbr.conf raw ${IFACE}
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

echo "4. Enable rinetd-bbr Service"
systemctl enable rinetd-bbr.service

echo "5. Start rinetd-bbr Service"
systemctl start rinetd-bbr.service

if systemctl status rinetd-bbr >/dev/null; then
	echo "rinetd-bbr started."
	echo "$PORTS speed up completed."
	echo "vi /etc/rinetd-bbr.conf as needed."
	echo "killall -9 rinetd-bbr for restart."
else
	echo "rinetd-bbr failed."
fi
