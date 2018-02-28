# V2RAY 基于 NGINX 的 VMESS+WS+TLS+Website(Use Host) 
### HTTP Header 分流，随机生成Header，自带 Website，自带 Rinetd BBR 加速，支持OpenVZ，重装自动清除残余的 Http 服务，每天自动升级最新的 V2ray 内核。

使用：1.解析好域名； 2.运行一键安装脚本；
```
bash <(curl https://raw.githubusercontent.com/dylanbai8/V2Ray_ws-tls_Website_onekey/master/install.sh)
```
尽量使用 Debian8 , 如果需要修改配置，运行脚本重新安装一次即可。

### 申明：

此为 wulabing/V2Ray_ws-tls_bash_onekey 的另一个分歧版本

源作者网址：https://github.com/wulabing/V2Ray_ws-tls_bash_onekey
```
修改内容如下：
1.修改路径分流为 HTTP Header 分流（随机生成Header）；
2.增加 Website 伪装站点；
3.增加 Rinetd BBR 端口加速（支持OpenVZ）；
4.自动清除残余的 Http 服务（某些系统自带的 Apache2 以及重装脚本时需要清除的 Nginx ）；
5.每天凌晨自动升级 V2ray 最新内核。

注意事项：
minimal类精简系统在执行脚本前可能需要手动更新系统并安装curl。
apt-get update
apt-get install curl
此外精简类系统必须支持 Systemd。
```

### 其它与原版一致，详细说明请步移 https://github.com/wulabing/V2Ray_ws-tls_bash_onekey

