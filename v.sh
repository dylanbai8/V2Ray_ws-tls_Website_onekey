#!/bin/bash

#====================================================
#	System Request:Debian 7+/Ubuntu 14.04+/Centos 6+
#	Author:	wulabing & dylanbai8
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

#生成伪装路径
camouflage=`cat /dev/urandom | head -n 10 | md5sum | head -c 8`
hostheader=`cat /dev/urandom | head -n 10 | md5sum | head -c 8`

source /etc/os-release

v2ray_hello(){
echo ""
echo -e "${Info} ${GreenBG} 你正在执行 V2RAY 基于 NGINX 的 VMESS+WS+TLS+Website(Use Host)+Rinetd BBR 一键安装脚本 ${Font}"
echo ""
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

#检测系统版本
check_system(){
    
    if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]];then
        echo -e "${OK} ${GreenBG} 当前系统为 Centos ${VERSION_ID} ${Font} "
        INS="yum"
        echo -e "${OK} ${GreenBG} SElinux 设置中，请耐心等待，不要进行其他操作${Font} "
        setsebool -P httpd_can_network_connect 1
        echo -e "${OK} ${GreenBG} SElinux 设置完成 ${Font} "
        rpm -ivh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
        echo -e "${OK} ${GreenBG} Nginx rpm源 安装完成 ${Font}" 
    elif [[ "${ID}" == "debian" && ${VERSION_ID} -ge 8 ]];then
        echo -e "${OK} ${GreenBG} 当前系统为 Debian ${VERSION_ID} ${Font} "
        INS="apt"
    elif [[ "${ID}" == "ubuntu" && `echo "${VERSION_ID}" | cut -d '.' -f1` -ge 16 ]];then
        echo -e "${OK} ${GreenBG} 当前系统为 Ubuntu ${VERSION_ID} ${Font} "
        INS="apt"
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
	echo ""
    echo -e "${Info} ${GreenBG} 【配置 1/3 】请输入你的域名信息(如:www.bing.com)，请确保域名A记录已正确解析至服务器IP ${Font}"
    stty erase '^H' && read -p "请输入：" domain
    echo -e "${Info} ${GreenBG} 【配置 2/3 】请输入连接端口（默认:443 无特殊需求请直接按回车键） ${Font}"
    stty erase '^H' && read -p "请输入：" port
    [[ -z ${port} ]] && port="443"
    echo -e "${Info} ${GreenBG} 【配置 3/3 】请输入alterID（默认:64 无特殊需求请直接按回车键） ${Font}"
    stty erase '^H' && read -p "请输入：" alterID
    [[ -z ${alterID} ]] && alterID="64"
}

#强制清除可能残余的http服务 v2ray服务 关闭防火墙 更新源
apache_uninstall(){
    if [[ "${ID}" == "centos" ]];then

	systemctl disable httpd
	systemctl stop httpd
	yum erase httpd -y

	systemctl disable nginx
	systemctl stop nginx
	yum erase nginx -y

	systemctl disable v2ray
	systemctl stop v2ray
	killall -9 v2ray

	systemctl disable firewalld
	systemctl stop firewalld

	yum -y update

    else

    systemctl disable apache2
	systemctl stop apache2
	apt purge apache2 -y	

    systemctl disable nginx
	systemctl stop nginx
	apt purge nginx -y

    systemctl disable v2ray
	systemctl stop v2ray
	killall -9 v2ray

	apt -y update

    fi
}

#安装各种依赖工具
dependency_install(){
    ${INS} install wget curl lsof -y

    if [[ "${ID}" == "centos" ]];then
       ${INS} -y install crontabs
    else
        ${INS} -y install cron
    fi
    judge "安装 crontab"

    ${INS} install net-tools -y
    judge "安装 net-tools"

    ${INS} install bc -y
    judge "安装 bc"

    ${INS} install unzip -y
    judge "安装 unzip"
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
    wget  --no-check-certificate https://install.direct/go.sh

    ## wget http://install.direct/go.sh
    
    if [[ -f go.sh ]];then
        bash go.sh --force
        judge "安装 V2ray"
    else
        echo -e "${Error} ${RedBG} V2ray 安装文件下载失败，请检查下载地址是否可用 ${Font}"
        exit 4
    fi
}

#设置定时任务
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

#安装ssl依赖
ssl_install(){
    if [[ "${ID}" == "centos" ]];then
        ${INS} install socat nc -y        
    else
        ${INS} install socat netcat -y
    fi
    judge "安装 SSL 证书生成脚本依赖"

    curl  https://get.acme.sh | sh
    judge "安装 SSL 证书生成脚本"

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

#生成v2ray配置文件
v2ray_conf_add(){
    cat>${v2ray_conf_dir}/config.json<<EOF
{
  "inbound": {
    "port": 10000,
    "listen":"127.0.0.1",
    "protocol": "vmess",
    "settings": {
      "clients": [
        {
          "id": "UserUUID",
          "alterId": 64
        }
      ]
    },
    "streamSettings":{
      "network":"ws",
      "wsSettings": {
      "path": "/",
	  "headers": {
	  "Host": "www.PathHeader.com"
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
        listen 443 ssl;
        ssl_certificate       /etc/v2ray/v2ray.crt;
        ssl_certificate_key   /etc/v2ray/v2ray.key;
        ssl_protocols         TLSv1 TLSv1.1 TLSv1.2;
        ssl_ciphers           HIGH:!aNULL:!MD5;
        server_name           serveraddr.com;
		root				  /www;
        location / {
        proxy_redirect off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
		if (\$http_host = "www.PathHeader.com" ) {
		proxy_pass http://127.0.0.1:10000;
		}
        }
	}
	server {
		SETPORT80;
		server_name serveraddr.com;
		SETREWRITE;
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
			"8.8.4.4"
		]
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
    let PORT=$RANDOM+10000
    UUID=$(cat /proc/sys/kernel/random/uuid)
    sed -i "/\"port\"/c  \    \"port\":${PORT}," ${v2ray_conf}
    sed -i "/\"id\"/c \\\t  \"id\":\"${UUID}\"," ${v2ray_conf}
    sed -i "/\"alterId\"/c \\\t  \"alterId\":${alterID}" ${v2ray_conf}
	sed -i "s/PathHeader/${hostheader}/g" "${v2ray_conf}"
}

#修正nginx配置配置文件
modify_nginx(){
    sed -i "1,/listen/{s/listen 443 ssl;/listen ${port} ssl;/}" ${nginx_conf}
    sed -i "/server_name/c \\\tserver_name ${domain};" ${nginx_conf}
    sed -i "/proxy_pass/c \\\tproxy_pass http://127.0.0.1:${PORT};" ${nginx_conf}
	sed -i "s/PathHeader/${hostheader}/g" "${nginx_conf}"
	sed -i "s/SETPORT80/listen 80/g" "${nginx_conf}"
	sed -i "s/SETREWRITE/rewrite ^ https:\/\/${domain}:${port}\$request_uri? permanent/g" "${nginx_conf}"
}

#修正客户端json配置文件
modify_userjson(){
	sed -i "s/SETDOMAIN/${domain}/g" "${v2ray_user}"
	sed -i "s/SETPORT/${port}/g" "${v2ray_user}"
	sed -i "s/SETID/${UUID}/g" "${v2ray_user}"
	sed -i "s/SETAID/${alterID}/g" "${v2ray_user}"
	sed -i "s/SETPATH/www.${hostheader}.com/g" "${v2ray_user}"
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
    echo -e "${Green} 加密方式（security）：${Font} 自适应 或 auto "
    echo -e "${Green} 传输协议（network）：${Font} 选 ws 或 websocket "
    echo -e "${Green} 伪装类型（type）：${Font} none "
    echo -e "${Green} WS 路径（Path）（WebSocket 路径）：${Font} / "
    echo -e "${Green} WS Host（Host）：${Font} www.${hostheader}.com "
    echo -e "${Green} 伪装域名（适用于 v2rayNG）：${Font} /;www.${hostheader}.com "
    echo -e "${Green} HTTP头（适用于 BifrostV）：${Font} 字段名：host 值：www.${hostheader}.com "
    echo -e "${Green} Mux 多路复用：${Font} 自适应 "
    echo -e "${Green} 底层传输安全：${Font} tls "
    if [ "${port}" -eq "443" ];then
    echo -e "${Green} Website 伪装站点：${Font} https://${domain} "
    echo -e "${Green} 客户端配置文件下载地址（URL）：${Font} https://${domain}/s/${camouflage}/config.json ${Green} 【推荐】 ${Font} "
    else
    echo -e "${Green} Website 伪装站点：${Font} https://${domain}:${port} "
    echo -e "${Green} 客户端配置文件下载地址（URL）：${Font} https://${domain}:${port}/s/${camouflage}/config.json ${Green} 【推荐】 ${Font} "
    fi
	echo -e "----------------------------------------------------------"
}

#命令块执行列表
main(){
	v2ray_hello
	is_root
	check_system
	port_alterid_set
	apache_uninstall
	dependency_install
	domain_check
    port_exist_check 80
    port_exist_check ${port}
	time_modify
	v2ray_install
	modify_crontab
	nginx_install
	web_install
	ssl_install
	acme
	v2ray_conf_add
	nginx_conf_add
	user_config_add
	rinetdbbr_install
	show_information
	start_process_systemd
}

rm_userjson(){
	rm -rf /www/s
    echo -e "${OK} ${GreenBG} 客户端配置文件 config.json 已从 Website 中删除 ${Font} "
}

new_uuid(){
    NEWUUID=$(cat /proc/sys/kernel/random/uuid)
	newcamouflage=`cat /dev/urandom | head -n 10 | md5sum | head -c 8`
    sed -i "/\"id\"/c \\\t  \"id\":\"${NEWUUID}\"," ${v2ray_conf}
    sed -i "/\"id\"/c \\\t  \"id\":\"${NEWUUID}\"" ${v2ray_user}
	rm -rf /www/s
    mkdir /www/s
    mkdir /www/s/${newcamouflage}
	cp -rp ${v2ray_user} /www/s/${newcamouflage}/config.json
    systemctl restart v2ray
    judge "V2ray 重启"
    echo -e "${Info} ${GreenBG} 新的 用户id（UUID）: ${NEWUUID} ${Font} "
    echo -e "${Info} ${GreenBG} 新的 客户端配置文件下载地址（URL）：https://你的域名:端口/s/${newcamouflage}/config.json ${Font} "
}

if [[ $# > 0 ]];then
    key="$1"
    case $key in
        -r|--rm_userjson)
        rm_userjson
        ;;
        -n|--new_uuid)
        new_uuid
        ;;
    esac
else
    main
fi
