




modify_crontab(){
    echo -e "${OK} ${GreenBG} 正在配置每天凌晨自动升级V2ray内核任务 ${Font}"
    sleep 2
	crontab -l >> crontab_tmp.txt
	echo "20 1 * * * bash /root/v2ray/go.sh | tee -a /root/v2ray/update.log" >> crontab.txt
	echo "30 1 * * * /sbin/reboot" >> crontab.txt
	crontab crontab.txt
    sleep 2
	/etc/init.d/cron restart
	rm -f crontab.txt
	rm -f crontab_tmp.txt
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
    echo -e "${OK} ${GreenBG} 按提示输入“443”或其它需要加速的端口 ${Font}"
    sleep 2
	bash get-rinetd.sh
	rm -f get-rinetd.sh
}




配置信息
----------------------------------------

    echo -e "${Red} 伪装域名（不要忘记斜杠/）：${Font} /;www.${UUID2}.com "


	
	
	
	
	