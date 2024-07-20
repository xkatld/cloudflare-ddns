# 使用说明
环境：Alpine3.20
下载脚本编辑一下加到crontab里就完事了  
```shell
apk add jq curl
wget https://raw.githubusercontent.com/xkatld/cloudflare-ddns/main/cfddns.sh -O /usr/local/bin/cfddns.sh
chmod +x /usr/local/bin/cfddns.sh
vi /usr/local/bin/cfddns.sh
```

修改`# 定义默认变量`运行即可定时命令即可

```shell
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/cfddns.sh >> /var/log/cfddns.log 2>&1") | crontab -
```
