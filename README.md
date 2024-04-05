# cloudflare-api-v4-ddns
cloudflare 一键 ddns 脚本 (大陆可用)  
下载`cf-v4-ddns.sh`编辑一下加到crontab里就完事了  
```
wget https://raw.githubusercontent.com/xkatld/cloudflare-api-v4-ddns/main/cf-v4-ddns.sh -O /usr/local/bin/cf-ddns.sh
chmod +x /usr/local/bin/cf-ddns.sh
vi /usr/local/bin/cf-ddns.sh
```  
修改`default config`下的几个配置变量  
[其中CFTOKEN填的是API Token，中文叫API令牌，别填了下面的API Key](https://dash.cloudflare.com/profile/api-tokens)  
`crontab -e`  
`*/2 * * * * /usr/local/bin/cf-ddns.sh >> /var/log/cf-ddns.log 2>&1`  
