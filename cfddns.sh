#!/usr/bin/env bash
set -o errexit
set -o nounset

# 定义默认变量
CFTOKEN=""        # Cloudflare API令牌
CFZONE_NAME=""    # 域名，例如：example.com
CFRECORD_NAME=""  # 需要更新的主机名，例如：homeserver.example.com
CFRECORD_TYPE="A" # DNS记录类型，A为IPv4，AAAA为IPv6
CFTTL=120         # Cloudflare上设置的TTL（生存时间），单位为秒
FORCE=false       # 是否强制更新IP，即使IP没有变化
CFFILE_PATH="$HOME/.cf"  # 存储配置和缓存文件的路径
WANIPSITE="http://v4.ipv6-test.com/api/myip.php"  # 用于获取IPv4地址的网站
NOW_DATE_TIME=$(date "+%Y-%m-%d %H:%M:%S")  # 当前日期时间，用于日志

# 解析命令行参数
while getopts k:h:z:t:f:p: opts; do
  case ${opts} in
    k) CFTOKEN=${OPTARG} ;;
    h) CFRECORD_NAME=${OPTARG} ;;
    z) CFZONE_NAME=${OPTARG} ;;
    t) CFRECORD_TYPE=${OPTARG} ;;
    f) FORCE=${OPTARG} ;;
    p) CFFILE_PATH=${OPTARG} ;;
  esac
done

# 如果记录类型是AAAA（IPv6），更改IP获取网站
[[ "$CFRECORD_TYPE" == "AAAA" ]] && WANIPSITE="http://v6.ipv6-test.com/api/myip.php"

# 创建配置文件目录
mkdir -p "$CFFILE_PATH"

# 检查必要参数
[[ -z "$CFTOKEN" ]] && { echo "$NOW_DATE_TIME 错误：缺少API密钥，请使用-k参数提供"; exit 2; }
[[ -z "$CFRECORD_NAME" ]] && { echo "$NOW_DATE_TIME 错误：缺少主机名，请使用-h参数提供"; exit 2; }
[[ -z "$CFZONE_NAME" ]] && { echo "$NOW_DATE_TIME 错误：缺少域名，请使用-z参数提供"; exit 2; }

# 确保记录名是FQDN（完全限定域名）
[[ "$CFRECORD_NAME" != "$CFZONE_NAME" && -n "${CFRECORD_NAME##*$CFZONE_NAME}" ]] && CFRECORD_NAME="$CFRECORD_NAME.$CFZONE_NAME"

# 获取当前WAN IP
WAN_IP=$(curl -s ${WANIPSITE})
WAN_IP_FILE="$CFFILE_PATH/.cf-wan_ip_$CFRECORD_NAME.txt"
OLD_WAN_IP=$(cat "$WAN_IP_FILE" 2>/dev/null || echo "")

# 如果IP未变更且未强制更新，退出脚本
if [[ "$WAN_IP" == "$OLD_WAN_IP" && "$FORCE" != true ]]; then
  echo "$NOW_DATE_TIME IP未变更，无需更新。如需强制更新，请使用 -f true 参数。"
  exit 0
fi

# 获取zone_identifier和record_identifier
ID_FILE="$CFFILE_PATH/.cf-id_$CFRECORD_NAME.txt"
if [[ -f $ID_FILE && $(wc -l < "$ID_FILE") == 4 && 
      "$(sed -n '3p' "$ID_FILE")" == "$CFZONE_NAME" && 
      "$(sed -n '4p' "$ID_FILE")" == "$CFRECORD_NAME" ]]; then
    CFZONE_ID=$(sed -n '1p' "$ID_FILE")
    CFRECORD_ID=$(sed -n '2p' "$ID_FILE")
else
    echo "$NOW_DATE_TIME 正在获取Cloudflare区域ID和记录ID..."
    CFZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$CFZONE_NAME" \
                -H "Authorization: Bearer $CFTOKEN" \
                -H "Content-Type: application/json" | 
                grep -Po '(?<="id":")[^"]*' | head -1)
    
    CFRECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?name=$CFRECORD_NAME" \
                  -H "Authorization: Bearer $CFTOKEN" \
                  -H "Content-Type: application/json" | 
                  grep -Po '(?<="id":")[^"]*' | head -1)
    
    printf "%s\n%s\n%s\n%s\n" "$CFZONE_ID" "$CFRECORD_ID" "$CFZONE_NAME" "$CFRECORD_NAME" > "$ID_FILE"
fi

echo "$NOW_DATE_TIME 正在更新DNS记录 $CFRECORD_NAME 到 $WAN_IP"

# 发送更新请求到Cloudflare API
RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records/$CFRECORD_ID" \
  -H "Authorization: Bearer $CFTOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"type\":\"$CFRECORD_TYPE\",\"name\":\"$CFRECORD_NAME\",\"content\":\"$WAN_IP\",\"ttl\":$CFTTL}")

# 检查更新是否成功
if [[ "$RESPONSE" == *'"success":true'* ]]; then
  echo "$NOW_DATE_TIME DNS记录更新成功！"
  echo "$WAN_IP" > "$WAN_IP_FILE"
else
  echo "$NOW_DATE_TIME DNS记录更新失败"
  echo "$NOW_DATE_TIME API响应: $RESPONSE"
  exit 1
fi
