#!/bin/bash

#====================================================
#	System Request:Debian 7+/Ubuntu 14.04+/Centos 6+
#	Author: wulabing & dylanbai8
#	Dscription: V2RAY 基于 NGINX 的 VMESS+WS+TLS+Website(Use Host)+Rinetd BBR
#	Blog: https://www.wulabing.com https://oo0.bid
#	Official document: www.v2ray.com
#====================================================

#定义文字颜色
Green="\033[32m" 
Red="\033[31m" 
Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

#定义提示信息
Info="${Green}[信息]${Font}"
OK="${Green}[OK]${Font}"
Error="${Red}[错误]${Font}"

#定义配置文件路径
v2ray_conf_dir="/etc/v2ray"
nginx_conf_dir="/etc/nginx/conf.d"
v2ray_conf="${v2ray_conf_dir}/config.json"
v2ray_user="${v2ray_conf_dir}/user.json"
nginx_conf="${nginx_conf_dir}/v2ray.conf"

source /etc/os-release

#脚本欢迎语
v2ray_hello(){
	echo ""
	echo -e "${Info} ${GreenBG} 你正在执行 V2RAY 基于 NGINX 的 VMESS+WS+TLS+Website(Use Host)+Rinetd BBR 一键安装脚本 ${Font}"
	echo ""
	random_number
}

#生成 转发端口 UUID 随机路径 伪装域名
random_number(){
	let PORT=$RANDOM+10000
	UUID=$(cat /proc/sys/kernel/random/uuid)
	camouflage=`cat /dev/urandom | head -n 10 | md5sum | head -c 8`
	hostheader=`cat /dev/urandom | head -n 10 | md5sum | head -c 8`
}

#检测root权限
is_root(){
	if [ `id -u` == 0 ]
		then echo -e "${OK} ${GreenBG} 当前用户是root用户，开始安装流程 ${Font} "
		sleep 3
	else
		echo -e "${Error} ${RedBG} 当前用户不是root用户，请切换到root用户后重新执行脚本 ${Font}"
		exit 1
	fi
}

#从VERSION中提取发行版系统的英文名称，为了在debian/ubuntu下添加相对应的Nginx apt源
VERSION=`echo ${VERSION} | awk -F "[()]" '{print $2}'`

#检测系统版本并添加源
check_system(){
	
	if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]];then
		echo -e "${OK} ${GreenBG} 当前系统为 Centos ${VERSION_ID} ${VERSION} ${Font} "
		INS="yum"
		echo -e "${OK} ${GreenBG} SElinux 设置中，请耐心等待，不要进行其他操作${Font} "
		setsebool -P httpd_can_network_connect 1 >/dev/null 2>&1
		echo -e "${OK} ${GreenBG} SElinux 设置完成 ${Font} "
		## 添加 Nginx apt源
		cat>/etc/yum.repos.d/nginx.repo<<EOF
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/mainline/centos/7/\$basearch/
gpgcheck=0
enabled=1
EOF
		echo -e "${OK} ${GreenBG} Nginx 源 安装完成 ${Font}"
	elif [[ "${ID}" == "debian" && ${VERSION_ID} -ge 8 ]];then
		echo -e "${OK} ${GreenBG} 当前系统为 Debian ${VERSION_ID} ${VERSION} ${Font} "
		INS="apt"
		## 添加 Nginx apt源
		if [ ! -f nginx_signing.key ];then
		echo "deb http://nginx.org/packages/mainline/debian/ ${VERSION} nginx" >> /etc/apt/sources.list
		echo "deb-src http://nginx.org/packages/mainline/debian/ ${VERSION} nginx" >> /etc/apt/sources.list
		wget -nc https://nginx.org/keys/nginx_signing.key >/dev/null 2>&1
		apt-key add nginx_signing.key >/dev/null 2>&1
		fi
	elif [[ "${ID}" == "ubuntu" && `echo "${VERSION_ID}" | cut -d '.' -f1` -ge 16 ]];then
		echo -e "${OK} ${GreenBG} 当前系统为 Ubuntu ${VERSION_ID} ${VERSION_CODENAME} ${Font} "
		INS="apt"
		## 添加 Nginx apt源
		if [ ! -f nginx_signing.key ];then
		echo "deb http://nginx.org/packages/mainline/ubuntu/ ${VERSION_CODENAME} nginx" >> /etc/apt/sources.list
		echo "deb-src http://nginx.org/packages/mainline/ubuntu/ ${VERSION_CODENAME} nginx" >> /etc/apt/sources.list
		wget -nc https://nginx.org/keys/nginx_signing.key >/dev/null 2>&1
		apt-key add nginx_signing.key >/dev/null 2>&1
		fi
	else
		echo -e "${Error} ${RedBG} 当前系统为 ${ID} ${VERSION_ID} 不在支持的系统列表内，安装中断 ${Font} "
		exit 1
	fi

}

#检测安装完成或失败
judge(){
	if [[ $? -eq 0 ]];then
		echo -e "${OK} ${GreenBG} $1 完成 ${Font}"
		sleep 1
	else
		echo -e "${Error} ${RedBG} $1 失败${Font}"
		exit 1
	fi
}

#用户设定 域名 端口 alterID
port_alterid_set(){
	echo -e "${Info} ${GreenBG} 【配置 1/3 】请输入你的域名信息(如:www.bing.com)，请确保域名A记录已正确解析至服务器IP ${Font}"
	stty erase '^H' && read -p "请输入：" domain
	echo -e "${Info} ${GreenBG} 【配置 2/3 】请输入连接端口（默认:443 无特殊需求请直接按回车键） ${Font}"
	stty erase '^H' && read -p "请输入：" port
	[[ -z ${port} ]] && port="443"
	echo -e "${Info} ${GreenBG} 【配置 3/3 】请输入alterID（默认:64 无特殊需求请直接按回车键） ${Font}"
	stty erase '^H' && read -p "请输入：" alterID
	[[ -z ${alterID} ]] && alterID="64"
	echo -e "----------------------------------------------------------"
	echo -e "${Info} ${GreenBG} 你输入的配置信息为 域名：${domain} 端口：${port} alterID：${alterID} ${Font}"
	echo -e "----------------------------------------------------------"
}

#强制清除可能残余的http服务 v2ray服务 关闭防火墙 更新源
apache_uninstall(){
	echo -e "${Info} ${GreenBG} 正在强制清理可能残余的http服务 ${Font}"
	if [[ "${ID}" == "centos" ]];then

	systemctl disable httpd >/dev/null 2>&1
	systemctl stop httpd >/dev/null 2>&1
	yum erase httpd httpd-tools apr apr-util -y >/dev/null 2>&1

	systemctl disable nginx >/dev/null 2>&1
	systemctl stop nginx >/dev/null 2>&1
	yum erase nginx -y >/dev/null 2>&1

	systemctl disable v2ray >/dev/null 2>&1
	systemctl stop v2ray >/dev/null 2>&1
	killall -9 v2ray >/dev/null 2>&1

	systemctl disable firewalld >/dev/null 2>&1
	systemctl stop firewalld >/dev/null 2>&1

	echo -e "${Info} ${GreenBG} 正在更新源 请稍后 …… ${Font}"

	yum -y update

	else

	systemctl disable apache2 >/dev/null 2>&1
	systemctl stop apache2 >/dev/null 2>&1
	apt purge apache2 -y >/dev/null 2>&1

	systemctl disable nginx >/dev/null 2>&1
	systemctl stop nginx >/dev/null 2>&1
	apt purge nginx -y >/dev/null 2>&1

	systemctl disable v2ray >/dev/null 2>&1
	systemctl stop v2ray >/dev/null 2>&1
	killall -9 v2ray >/dev/null 2>&1

	echo -e "${Info} ${GreenBG} 正在更新源 请稍后 …… ${Font}"

	apt -y update

	fi

	rm -rf /www >/dev/null 2>&1
	rm -rf /etc/v2ray/config.json >/dev/null 2>&1
	rm -rf /etc/v2ray/user.json >/dev/null 2>&1
	rm -rf /etc/nginx/conf.d/v2ray.conf >/dev/null 2>&1
}

#安装各种依赖工具
dependency_install(){
	${INS} install curl lsof unzip zip -y

	if [[ "${ID}" == "centos" ]];then
		${INS} -y install crontabs
	else
		${INS} -y install cron
	fi
	judge "安装 crontab"

	${INS} install bc -y
	judge "安装 bc"
}

#检测域名解析是否正确
domain_check(){
	domain_ip=`ping ${domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
	echo -e "${OK} ${GreenBG} 正在获取 公网ip 信息，请耐心等待 ${Font}"
	local_ip=`curl -4 ip.sb`
	echo -e "${OK} ${GreenBG} 域名dns解析IP：${domain_ip} ${Font}"
	echo -e "${OK} ${GreenBG} 本机IP: ${local_ip} ${Font}"
	sleep 2
	if [[ $(echo ${local_ip}|tr '.' '+'|bc) -eq $(echo ${domain_ip}|tr '.' '+'|bc) ]];then
		echo -e "${OK} ${GreenBG} 域名dns解析IP  与 本机IP 匹配 域名解析正确 ${Font}"
		sleep 2
	else
		echo -e "${Error} ${RedBG} 域名dns解析IP 与 本机IP 不匹配 是否继续安装？（y/n）${Font}" && read install
		case $install in
		[yY][eE][sS]|[yY])
			echo -e "${GreenBG} 继续安装 ${Font}"
			sleep 2
			;;
		*)
			echo -e "${RedBG} 安装终止 ${Font}"
			exit 2
			;;
		esac
	fi
}

#检测端口是否占用
port_exist_check(){
	if [[ 0 -eq `lsof -i:"$1" | wc -l` ]];then
		echo -e "${OK} ${GreenBG} $1 端口未被占用 ${Font}"
		sleep 1
	else
		echo -e "${Error} ${RedBG} 检测到 $1 端口被占用，以下为 $1 端口占用信息 ${Font}"
		lsof -i:"$1"
		echo -e "${OK} ${GreenBG} 5s 后将尝试自动 kill 占用进程 ${Font}"
		sleep 5
		lsof -i:"$1" | awk '{print $2}'| grep -v "PID" | xargs kill -9
		echo -e "${OK} ${GreenBG} kill 完成 ${Font}"
		sleep 1
	fi
}

#同步服务器时间
time_modify(){

	${INS} install ntpdate -y
	judge "安装 NTPdate 时间同步服务 "

	systemctl stop ntp &>/dev/null

	echo -e "${Info} ${GreenBG} 正在进行时间同步 ${Font}"
	ntpdate time.nist.gov

	if [[ $? -eq 0 ]];then 
		echo -e "${OK} ${GreenBG} 时间同步成功 ${Font}"
		echo -e "${OK} ${GreenBG} 当前系统时间 `date -R`（时区时间换算后误差应为三分钟以内）${Font}"
		sleep 1
	else
		echo -e "${Error} ${RedBG} 时间同步失败，请检查ntpdate服务是否正常工作 ${Font}"
	fi 
}

#安装v2ray主程序
v2ray_install(){
	if [[ -d /root/v2ray ]];then
		rm -rf /root/v2ray
	fi

	mkdir -p /root/v2ray && cd /root/v2ray
	wget -N --no-check-certificate https://install.direct/go.sh
	
	if [[ -f go.sh ]];then
		bash go.sh --force
		judge "安装 V2ray"
	else
		echo -e "${Error} ${RedBG} V2ray 安装文件下载失败，请检查下载地址是否可用 ${Font}"
		exit 4
	fi
}

#设置定时升级任务
modify_crontab(){
	echo -e "${OK} ${GreenBG} 配置每天凌晨自动升级V2ray内核任务 ${Font}"
	sleep 2
	#crontab -l >> crontab.txt
	echo "20 12 * * * bash /root/v2ray/go.sh | tee -a /root/v2ray/update.log" >> crontab.txt
	echo "30 12 * * * /sbin/reboot" >> crontab.txt
	crontab crontab.txt
	sleep 2
	if [[ "${ID}" == "centos" ]];then
		systemctl restart crond
	else
		systemctl restart cron
	fi
	rm -f crontab.txt
}

#安装ssl依赖
ssl_install(){
	if [[ "${ID}" == "centos" ]];then
		${INS} install socat nc -y
	else
		${INS} install socat netcat -y
	fi
	judge "安装 SSL 证书生成脚本依赖"

	curl  https://get.acme.sh | sh
	judge "安装 SSL 证书生成脚本 添加证书自动续签任务"

}

#生成ssl证书
acme(){
	~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256 --force
	if [[ $? -eq 0 ]];then
		echo -e "${OK} ${GreenBG} SSL 证书生成成功 ${Font}"
		sleep 2
		~/.acme.sh/acme.sh --installcert -d ${domain} --fullchainpath /etc/v2ray/v2ray.crt --keypath /etc/v2ray/v2ray.key --ecc
		if [[ $? -eq 0 ]];then
		echo -e "${OK} ${GreenBG} 证书配置成功 ${Font}"
		sleep 2
		fi
	else
		echo -e "${Error} ${RedBG} SSL 证书生成失败 ${Font}"
		exit 1
	fi
}

#安装nginx主程序
nginx_install(){
	${INS} install nginx -y
	if [[ -d /etc/nginx ]];then
		echo -e "${OK} ${GreenBG} nginx 安装完成 ${Font}"
		sleep 2
	else
		echo -e "${Error} ${RedBG} nginx 安装失败 ${Font}"
		exit 5
	fi
}

#安装web伪装站点
web_install(){
	echo -e "${OK} ${GreenBG} 安装Website伪装站点 ${Font}"
	sleep 2
	mkdir /www
	wget https://github.com/dylanbai8/V2Ray_ws-tls_Website_onekey/raw/master/V2rayWebsite.tar.gz
	tar -zxvf V2rayWebsite.tar.gz -C /www
	rm -f V2rayWebsite.tar.gz
}

#生成v2ray配置文件
v2ray_conf_add(){
	cat>${v2ray_conf_dir}/config.json<<EOF
{
  "inbound": {
	"port": SETPORTV,
	"listen": "127.0.0.1",
	"protocol": "vmess",
	"settings": {
	  "clients": [
		{
		  "id": "SETUUID",
		  "alterId": SETALTERID
		}
	  ]
	},
	"streamSettings": {
	  "network": "ws",
	  "wsSettings": {
	  "path": "/",
	  "headers": {
	  "Host": "www.SETHEADER.com"
	  }
	  }
	}
  },
  "outbound": {
	"protocol": "freedom",
	"settings": {}
  }
}
EOF

modify_port_UUID
judge "V2ray 配置"
}

#生成nginx配置文件
nginx_conf_add(){
	touch ${nginx_conf_dir}/v2ray.conf
	cat>${nginx_conf_dir}/v2ray.conf<<EOF
	server {
		listen SETPORT443 ssl http2;
		ssl_certificate		/etc/v2ray/v2ray.crt;
		ssl_certificate_key	/etc/v2ray/v2ray.key;
		ssl_protocols		TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
		ssl_ciphers			HIGH:!aNULL:!MD5;
		server_name			SETSERVER.COM;
		root		/www;
		location / {
		proxy_redirect off;
		proxy_http_version 1.1;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection "upgrade";
		proxy_set_header Host \$http_host;
		if (\$http_host = "www.SETHEADER.com" ) {
		proxy_pass http://127.0.0.1:SETPORTV;
		}
		}
	}
	server {
		listen 80;
		server_name SETSERVER.COM;
		return 301 https://SETSERVER.COM:SETPORT443;
	}
EOF

modify_nginx
judge "Nginx 配置"

}

#生成客户端json文件
user_config_add(){
	touch ${v2ray_conf_dir}/user.json
	cat>${v2ray_conf_dir}/user.json<<EOF
{
	"log": {
		"loglevel": "info",
		"access": "",
		"error": ""
	},
	"dns": {
		"servers": [
			"8.8.8.8",
			"1.1.1.1",
			"119.29.29.29",
			"114.114.114.114"
		]
	},
	"inbound": {
		"port": 1087,
		"listen": "127.0.0.1",
		"protocol": "http",
		"settings": {
			"timeout": 600
		}
	},
	"inboundDetour": [
		{
			"port": 1080,
			"listen": "127.0.0.1",
			"protocol": "socks",
			"settings": {
				"auth": "noauth",
				"timeout": 600,
				"udp": true
			}
		}
	],
	"outbound": {
		"tag": "agentout",
		"protocol": "vmess",
		"mux": {
			"enabled": true,
			"concurrency": 6
		},
		"streamSettings": {
			"network": "ws",
			"security": "tls",
			"wsSettings": {
				"path": "/",
				"headers": {
					"host": "SETHEADER"
				}
			}
		},
		"settings": {
			"vnext": [
				{
					"port": SETPORT443,
					"address": "SETSERVER",
					"users": [
						{
							"alterId": SETALTERID,
							"id": "SETUUID"
						}
					]
				}
			]
		}
	},
	"outboundDetour": [
		{
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
	"routing": {
		"strategy": "rules",
		"settings": {
			"domainStrategy": "IPIfNonMatch",
			"rules": [
				{
					"type": "field",
					"outboundTag": "agentout",
					"ip": [
						"8.8.8.8",
						"1.1.1.1"
					]
				},
				{
					"type": "field",
					"outboundTag": "direct",
					"ip": [
						"119.29.29.29",
						"114.114.114.114"
					]
				},
				{
					"type": "field",
					"outboundTag": "direct",
					"ip": [
						"geoip:private"
					]
				},
				{
					"type": "chinasites",
					"outboundTag": "direct"
				},
				{
					"type": "chinaip",
					"outboundTag": "direct"
				},
				{
					"type": "field",
					"outboundTag": "direct",
					"domain": [
						"geosite:cn"
					]
				},
				{
					"type": "field",
					"outboundTag": "direct",
					"ip": [
						"geoip:cn"
					]
				}
			]
		}
	}
}
EOF

modify_userjson

	rm -rf /www/s
	mkdir /www/s
	mkdir /www/s/${camouflage}
	cp -rp ${v2ray_user} /www/s/${camouflage}/config.json

judge "客户端json配置"
}

#修正v2ray配置文件
modify_port_UUID(){
	sed -i "s/SETPORTV/${PORT}/g" "${v2ray_conf}"
	sed -i "s/SETUUID/${UUID}/g" "${v2ray_conf}"
	sed -i "s/SETALTERID/${alterID}/g" "${v2ray_conf}"
	sed -i "s/SETHEADER/${hostheader}/g" "${v2ray_conf}"
}

#修正nginx配置配置文件
modify_nginx(){
	sed -i "s/SETPORT443/${port}/g" "${nginx_conf}"
	sed -i "s/SETPORTV/${PORT}/g" "${nginx_conf}"
	sed -i "s/SETSERVER.COM/${domain}/g" "${nginx_conf}"
	sed -i "s/SETHEADER/${hostheader}/g" "${nginx_conf}"
}

#修正客户端json配置文件
modify_userjson(){
	sed -i "s/SETSERVER/${domain}/g" "${v2ray_user}"
	sed -i "s/SETPORT443/${port}/g" "${v2ray_user}"
	sed -i "s/SETUUID/${UUID}/g" "${v2ray_user}"
	sed -i "s/SETALTERID/${alterID}/g" "${v2ray_user}"
	sed -i "s/SETHEADER/www.${hostheader}.com/g" "${v2ray_user}"
}

#安装bbr端口加速
rinetdbbr_install(){
	export RINET_URL="https://drive.google.com/uc?id=0B0D0hDHteoksVzZ4MG5hRkhqYlk"

	for CMD in curl iptables grep cut xargs systemctl ip awk
	do
		if ! type -p ${CMD}; then
			echo -e "\e[1;31mtool ${CMD} 缺少依赖 Rinetd BBR 终止安装 \e[0m"
			exit 1
		fi
	done

	systemctl disable rinetd-bbr.service
	killall -9 rinetd-bbr
	rm -rf /usr/bin/rinetd-bbr /etc/rinetd-bbr.conf /etc/systemd/system/rinetd-bbr.service

	echo -e "${OK} ${GreenBG} 下载Rinetd-BBR安装文件 ${Font}"
	curl -L "${RINET_URL}" >/usr/bin/rinetd-bbr
	chmod +x /usr/bin/rinetd-bbr

	echo -e "${OK} ${GreenBG} 配置 ${port} 为加速端口 ${Font}"
	cat <<EOF >> /etc/rinetd-bbr.conf
0.0.0.0 ${port} 0.0.0.0 ${port}
EOF

	IFACE=$(ip -4 addr | awk '{if ($1 ~ /inet/ && $NF ~ /^[ve]/) {a=$NF}} END{print a}')

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

	systemctl enable rinetd-bbr.service
	systemctl start rinetd-bbr.service

	if systemctl status rinetd-bbr >/dev/null; then
		echo -e "${OK} ${GreenBG} Rinetd-BBR 安装成功 ${Font}"
		echo -e "${OK} ${GreenBG} ${port} 端口加速成功 ${Font}"
	else
		echo -e "${Error} ${RedBG} Rinetd-BBR 安装失败 ${Font}"
	fi
}

#重启nginx和v2ray程序 加载配置
start_process_systemd(){
	systemctl enable v2ray >/dev/null 2>&1
	systemctl enable nginx >/dev/null 2>&1

	systemctl restart nginx
	judge "Nginx 启动"

	systemctl start v2ray
	judge "V2ray 启动"
}

#展示客户端配置信息
show_information(){
	clear
	echo ""
	echo -e "${Info} ${GreenBG} V2RAY 基于 NGINX 的 VMESS+WS+TLS+Website(Use Host)+Rinetd BBR 安装成功 ${Font} "
	echo -e "----------------------------------------------------------"
	echo -e "${Green} 【您的 V2ray 配置信息】 ${Font} "
	echo -e "${Green} 地址（address）：${Font} ${domain} "
	echo -e "${Green} 端口（port）：${Font} ${port} "
	echo -e "${Green} 用户id（UUID）：${Font} ${UUID} "
	echo -e "${Green} 额外id（alterId）：${Font} ${alterID} "
	echo -e "${Green} 加密方式（security）：${Font} 自适应（建议 none） "
	echo -e "${Green} 传输协议（network）：${Font} 选 ws 或 websocket "
	echo -e "${Green} 伪装类型（type）：${Font} none "
	echo -e "${Green} WS 路径（Path）（WebSocket 路径）：${Font} / "
	echo -e "${Green} WS Host（Host）：${Font} www.${hostheader}.com "
	echo -e "${Green} 伪装域名（适用于 v2rayNG）：${Font} /;www.${hostheader}.com "
	echo -e "${Green} HTTP头（适用于 BifrostV）：${Font} 字段名：host 值：www.${hostheader}.com "
	echo -e "${Green} Mux 多路复用：${Font} 自适应 "
	echo -e "${Green} 底层传输安全（加密方式）：${Font} tls "
	if [ "${port}" -eq "443" ];then
	echo -e "${Green} Website 伪装站点：${Font} https://${domain} "
	echo -e "${Green} 客户端配置文件下载地址（URL）：${Font} https://${domain}/s/${camouflage}/config.json ${Green} 【推荐】 ${Font} "
	echo -e "${Green} Windows 客户端（已打包 config 即下即用） ：${Font} https://${domain}/s/${camouflage}/V2rayPro.zip ${Green} 【推荐】 ${Font} "
	else
	echo -e "${Green} Website 伪装站点：${Font} https://${domain}:${port} "
	echo -e "${Green} 客户端配置文件下载地址（URL）：${Font} https://${domain}:${port}/s/${camouflage}/config.json ${Green} 【推荐】 ${Font} "
	echo -e "${Green} Windows 客户端（已打包 config 即下即用） ：${Font} https://${domain}:${port}/s/${camouflage}/V2rayPro.zip ${Green} 【推荐】 ${Font} "
	fi
	echo -e "----------------------------------------------------------"
}

#命令块执行列表
main_sslon(){
	is_root
	check_system
	v2ray_hello
	port_alterid_set
	apache_uninstall
	dependency_install
	domain_check
	port_exist_check 80
	port_exist_check ${port}
	time_modify
	v2ray_install
	modify_crontab
	ssl_install
	acme
	nginx_install
	web_install
	v2ray_conf_add
	nginx_conf_add
	user_config_add
	rinetdbbr_install
	win64_v2ray
	show_information
	start_process_systemd
}

main_ssloff(){
	is_root
	check_system
	v2ray_hello
	port_alterid_set
	apache_uninstall
	dependency_install
	domain_check
	port_exist_check 80
	port_exist_check ${port}
	time_modify
	v2ray_install
	modify_crontab
	ssl_install
	nginx_install
	web_install
	v2ray_conf_add
	nginx_conf_add
	user_config_add
	rinetdbbr_install
	win64_v2ray
	show_information
	start_process_systemd
}

main(){
if [[ -e /etc/v2ray/v2ray.key ]]; then
	echo -e "${Info} ${GreenBG} 提示：检测到你的服务器已经存在ssl证书 为避免重复申请 脚本将自动跳过该步骤 ${Font}"
	echo -e "${Info} ${GreenBG} 如果你已更换新的域名 请按 ctrl+c 退出 然后执行 bash v.sh -q 强制重装 ${Font}"
	read -p "按 回车键 继续 …… "
	main_ssloff
else
	main_sslon
fi
}

#删除website客户端配置文件 防止被抓取
rm_userjson(){
	rm -rf /www/s
	echo -e "${OK} ${GreenBG} 客户端配置文件 config.json 已从 Website 中删除 ${Font} "
	echo -e "${OK} ${GreenBG} 提示：如果忘记配置信息 可执行 bash v.sh -n 重新生成 ${Font} "
}

#生成新的UUID并重启服务
new_uuid(){
if [[ -e /www/index.bak ]]; then
	echo -e "${Info} ${GreenBG} 您已开启账号分享功能，无法手动更换 UUID 和生成 config.json 配置文件 ${Font}"
	echo -e "${Info} ${GreenBG} 提示：紧急更换共享 UUID 请执行 bash v.sh -m ${Font}"
else
	random_number
	sed -i "/\"id\"/c \\\t\t  \"id\":\"${UUID}\"," ${v2ray_conf}
	sed -i "/\"id\"/c \\\t\t\t\t\t\t\t\"id\":\"${UUID}\"" ${v2ray_user}
	rm -rf /www/s
	mkdir /www/s
	mkdir /www/s/${camouflage}
	cp -rp ${v2ray_user} /www/s/${camouflage}/config.json
	win64_v2ray
	systemctl restart v2ray
	judge "重启V2ray进程载入新的配置文件"
	echo -e "${OK} ${GreenBG} 新的 用户id（UUID）: ${UUID} ${Font} "
	echo -e "${OK} ${GreenBG} 新的 客户端配置文件下载地址（URL）：https://你的域名:端口/s/${camouflage}/config.json ${Font} "
	echo -e "${OK} ${GreenBG} 新的 Windows 客户端（已打包 config 即下即用）：https://你的域名:端口/s/${camouflage}/V2rayPro.zip ${Font} "
fi
}

#开启账号共享功能 增加每周一定时更换UUID任务
add_share(){
if [[ -e /www/index.bak ]]; then
	echo -e "${Info} ${GreenBG} 账号分享功能已开启，请勿重复操作 ${Font}"
else
	cp -rp /www/index.html /www/index.bak
	crontab -l >> crontab.txt
	echo "10 12 * * 1 bash /root/v.sh -m" >> crontab.txt
	crontab crontab.txt
	if [[ "${ID}" == "centos" ]];then
		systemctl restart crond
	else
		systemctl restart cron
	fi
	rm -f crontab.txt
	echo -e "${OK} ${GreenBG} 账号分享功能已开启 UUID 将在每周一12点10分更换（服务器时区）并推送至 Website 首页 ${Font}"
	echo -e "${OK} ${GreenBG} 提示：为避免被恶意抓取 该模式下不生成客户端 config.json 文件 ${Font}"
	echo -e "${OK} ${GreenBG} 正在执行首次 UUID 更换任务 ${Font}"
	bash /root/v.sh -m
fi
}

#每周一定时更换UUID并推送至website首页
share_uuid(){
	random_number
	rm -f /www/index.html
	cp -rp /www/index.bak /www/index.html
	sed -i "/\"id\"/c \\\t\t  \"id\":\"${UUID}\"," ${v2ray_conf}
	sed -i "s/<\/body>/<\/body><div style=\"color:#666666;\"><br\/><br\/><p align=\"center\">UUID:${UUID}<\/p><br\/><\/div>/g" "/www/index.html"
	systemctl restart v2ray
	echo -e "${OK} ${GreenBG} 执行 UUID 更换任务成功，请访问 Website 首页查看新的 UUID ${Font}"
}

#生成Windows客户端
win64_v2ray(){
	TAG_URL="https://api.github.com/repos/v2ray/v2ray-core/releases/latest"
	NEW_VER=`curl -s ${TAG_URL} --connect-timeout 10| grep 'tag_name' | cut -d\" -f4`
	wget https://github.com/dylanbai8/V2Ray_ws-tls_Website_onekey/raw/master/V2rayPro.zip
	wget https://github.com/v2ray/v2ray-core/releases/download/${NEW_VER}/v2ray-windows-64.zip
	echo -e "${OK} ${GreenBG} 正在生成Windows客户端 v2ray-core最新版本 ${NEW_VER} ${Font}"
	unzip V2rayPro.zip
	unzip v2ray-windows-64.zip
	rm -rf V2rayPro.zip v2ray-windows-64.zip
	mv ./V2rayPro/v2ray/wv2ray-service.exe ./v2ray-${NEW_VER}-windows-64
	rm -rf ./V2rayPro/v2ray
	mv ./v2ray-${NEW_VER}-windows-64 ./V2rayPro/v2ray
	cp -rp ${v2ray_user} ./V2rayPro/v2ray/config.json
	zip -q -r /www/s/${camouflage}/V2rayPro.zip ./V2rayPro
	rm -rf ./V2rayPro
}

#Bash执行选项
if [[ $# > 0 ]];then
	key="$1"
	case $key in
		-r|--rm_userjson)
		rm_userjson
		;;
		-n|--new_uuid)
		new_uuid
		;;
		-s|--add_share)
		add_share
		;;
		-m|--share_uuid)
		share_uuid
		;;
		-q|--main_sslon)
		main_sslon
		;;
	esac
else
	main
fi
