

header分流配置
-------------------------------------

### nginx_conf_add

		location / {


		if (\$http_host = "www.${UUID2}.com" ) {
		proxy_pass http://127.0.0.1:10000;
		}

### v2ray_conf_add


      "path": "/",
	  "headers": {
	  "Host": "www.\${UUID2}.com"
	  }

	  
定义uuid2
--------------------------------------

	UUID2=$(cat /proc/sys/kernel/random/uuid)
	


	
	
	
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
}

web_install(){
    echo -e "${OK} ${GreenBG} 正在安装Website伪装站点 ${Font}"
    sleep 2
	wget https://github.com/dylanbai8/V2Ray_ws-tls_Website_onekey/raw/master/V2rayWebsite.tar.gz
	tar -zxvf V2rayWebsite.tar.gz -C /usr/share/nginx/html/
	rm -f V2rayWebsite.tar.gz
}

rinetdbbr_install(){
    echo -e "${OK} ${GreenBG} 正在安装RinetdBBR加速服务 ${Font}"
    sleep 2
	wget https://raw.githubusercontent.com/linhua55/lkl_study/master/get-rinetd.sh
    echo -e "${OK} ${GreenBG} 按提示输入“443”或其它需要加速的端口 ${Font}"
    sleep 2
	bash get-rinetd.sh
	rm -f get-rinetd.sh
}




配置信息
----------------------------------------

    echo -e "${Red} 伪装域名（不要忘记斜杠/）：${Font} /;www.${UUID2}.com "


	
	
	
	
	