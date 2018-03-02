



user_config_add(){
    echo -e "${OK} ${GreenBG} 正在生成客户端 config.json 文件 ${Font}"
	UUID3=$(cat /proc/sys/kernel/random/uuid)
    mkdir /www/${UUID3}
    touch /www/${UUID3}/config.json
    cat>/www/${UUID3}/config.json<<EOF
{
	"outbound": {
		"streamSettings": {
			"network": "ws",
			"kcpSettings": null,
			"wsSettings": {
				"headers": {
					"host": "SETPATH"
				},
				"path": "/"
			},
			"tcpSettings": null,
			"tlsSettings": {},
			"security": "tls"
		},
		"tag": "agentout",
		"protocol": "vmess",
		"mux": {
			"enabled": true,
			"concurrency": 8
		},
		"settings": {
			"vnext": [{
				"users": [{
					"alterId": SETAID,
					"security": "aes-128-gcm",
					"id": "SETID"
				}],
				"port": SETPORT,
				"address": "SETDOMAIN"
			}]
		}
	},
	"log": {
		"access": "",
		"loglevel": "info",
		"error": ""
	},
	"outboundDetour": [{
			"tag": "direct",
			"protocol": "freedom",
			"settings": {
				"response": null
			}
		},
		{
			"tag": "blockout",
			"protocol": "blackhole",
			"settings": {
				"response": {
					"type": "http"
				}
			}
		}
	],
	"inbound": {
		"streamSettings": null,
		"settings": {
			"ip": "127.0.0.1",
			"udp": true,
			"clients": null,
			"auth": "noauth"
		},
		"protocol": "socks",
		"port": 1080,
		"listen": "0.0.0.0"
	},
	"inboundDetour": null,
	"routing": {
		"settings": {
			"rules": [{
					"ip": [
						"0.0.0.0/8",
						"10.0.0.0/8",
						"100.64.0.0/10",
						"127.0.0.0/8",
						"169.254.0.0/16",
						"172.16.0.0/12",
						"192.0.0.0/24",
						"192.0.2.0/24",
						"192.168.0.0/16",
						"198.18.0.0/15",
						"198.51.100.0/24",
						"203.0.113.0/24",
						"::1/128",
						"fc00::/7",
						"fe80::/10"
					],
					"domain": null,
					"type": "field",
					"port": null,
					"outboundTag": "direct"
				},
				{
					"type": "chinasites",
					"outboundTag": "direct"
				},
				{
					"type": "chinaip",
					"outboundTag": "direct"
				}
			],
			"domainStrategy": "IPIfNonMatch"
		},
		"strategy": "rules"
	},
	"dns": {
		"servers": [
			"8.8.8.8",
			"8.8.4.4",
			"localhost"
		]
	}
}
EOF
	sed -i "s/SETDOMAIN/${domain}/g" "/www/${UUID3}/config.json"
	sed -i "s/SETPORT/${port}/g" "/www/${UUID3}/config.json"
	sed -i "s/SETID/${UUID}/g" "/www/${UUID3}/config.json"
	sed -i "s/SETAID/${alterID}/g" "/www/${UUID3}/config.json"
	sed -i "s/SETPATH/www.${UUID2}.com/g" "/www/${UUID3}/config.json"
}





### nginx_conf_add
	server {
		SETPORT80;
		server_name serveraddr.com;
		REWRITE80;
	}

去掉 ssl on;

modify_crontab(){
    echo -e "${OK} ${GreenBG} 正在配置每天凌晨自动升级V2ray内核任务 ${Font}"
    sleep 2
	crontab -l >> crontab.txt
	echo "20 12 * * * bash /root/v2ray/go.sh | tee -a /root/v2ray/update.log" >> crontab.txt
	echo "30 12 * * * /sbin/reboot" >> crontab.txt
	crontab crontab.txt
    sleep 2
	/etc/init.d/cron restart
	rm -f crontab.txt
}




header分流配置
-------------------------------------

### nginx_conf_add
		root /www;
		location / {


		if (\$http_host = "www.PathUUID.com" ) {
		proxy_pass http://127.0.0.1:10000;
		}

### v2ray_conf_add


      "path": "/",
	  "headers": {
	  "Host": "www.PathUUID.com"
	  }

	  
定义uuid2
--------------------------------------

modify_PathUUID(){
	UUID2=$(cat /proc/sys/kernel/random/uuid)
	sed -i "s/PathUUID/${UUID2}/g" "/etc/nginx/conf.d/v2ray.conf"
	sed -i "s/SETPORT80/listen 80/g" "/etc/nginx/conf.d/v2ray.conf"
	sed -i "s/REWRITE80/rewrite ^(.*)\$ https:\/\/\${server_name}\$1 permanent/g" "/etc/nginx/conf.d/v2ray.conf"
	sed -i "s/PathUUID/${UUID2}/g" "/etc/v2ray/config.json"
}

	
	
	
新增
---------------------------------------

apache_uninstall(){
    echo -e "${OK} ${GreenBG} 正在尝试清楚残留HTTP服务 ${Font}"
    sleep 2
    service apache2 stop
    update-rc.d -f apache2 remove
    systemctl disable apache2
	systemctl stop apache2
	${INS} purge apache2 -y	
	service nginx stop
    update-rc.d -f nginx remove
    systemctl disable nginx
	systemctl stop nginx
	${INS} purge nginx -y
	service v2ray stop
    update-rc.d -f v2ray remove
    systemctl disable v2ray
	systemctl stop v2ray
}

web_install(){
    echo -e "${OK} ${GreenBG} 正在安装Website伪装站点 ${Font}"
    sleep 2
    mkdir /www
	wget https://github.com/dylanbai8/V2Ray_ws-tls_Website_onekey/raw/master/V2rayWebsite.tar.gz
	tar -zxvf V2rayWebsite.tar.gz -C /www
	rm -f V2rayWebsite.tar.gz
}

rinetdbbr_install(){
    echo -e "${OK} ${GreenBG} 正在安装RinetdBBR加速服务 ${Font}"
    sleep 2
	wget https://raw.githubusercontent.com/linhua55/lkl_study/master/get-rinetd.sh
    echo -e "${OK} ${GreenBG} 【按提示输入“443”或者其它需要加速的端口】不加速任何端口请直接按回车键 ${Font}"
    sleep 2
	bash get-rinetd.sh
	rm -f get-rinetd.sh
}




配置信息
----------------------------------------

show_information(){
    clear

    echo -e "${OK} ${GreenBG} V2RAY 基于 NGINX 的 VMESS+WS+TLS+Website(Use Host)+Rinetd BBR 安装成功 ${Font} "
	echo -e "----------------------------------------------------------"
    echo -e "${Green} 【您的 V2ray 配置信息】 ${Font} "
    echo -e "${Green} 地址（address）：${Font} ${domain} "
    echo -e "${Green} 端口（port）：${Font} ${port} "
    echo -e "${Green} 用户id（UUID）：${Font} ${UUID} "
    echo -e "${Green} 额外id（alterId）：${Font} ${alterID} "
    echo -e "${Green} 加密方式（security）：${Font} 自适应 "
    echo -e "${Green} 传输协议（network）：${Font} ws "
    echo -e "${Green} 伪装类型（type）：${Font} none "
    echo -e "${Green} 伪装域名（不要忘记斜杠/）：${Font} /;www.${UUID2}.com "
    echo -e "${Green} 底层传输安全：${Font} tls "
    echo -e "${Green} Website 伪装站点：${Font} https://${domain} "
    echo -e "${Green} 客户端配置文件下载地址（URL）：${Font} https://${domain}/${UUID3}/config.json "
	echo -e "----------------------------------------------------------"
}

