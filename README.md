# 使用说明
下载脚本编辑一下加到crontab里就完事了  
```
wget https://raw.githubusercontent.com/xkatld/cloudflare-ddns/main/cfddns.sh -O /usr/local/bin/cfddns.sh
chmod +x /usr/local/bin/cfddns.sh
vi /usr/local/bin/cfddns.sh
```  
修改`default config`下的几个配置变量  
[其中CFTOKEN填的是API Token，中文叫API令牌，别填了下面的API Key](https://dash.cloudflare.com/profile/api-tokens)  
`crontab -e`  
`*/2 * * * * /usr/local/bin/cfddns.sh >> /var/log/cfddns.log 2>&1`  
