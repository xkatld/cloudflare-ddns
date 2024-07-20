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
也可以通过自定义参数命令运行
```shell
/usr/local/bin/cfddns.sh -k <apikey> -e <邮箱> -z <域名> -h <二级域名> -t A
```
出现缓存错误可以通过下面命令清理缓存
```shell
rm -rf ~/.cf/
```
