#!/usr/bin/env bash
set -euo pipefail

# 定义默认变量
CFAPI_KEY=""
CFAPI_EMAIL=""
CFZONE_NAME=""
CFRECORD_NAME=""
CFRECORD_TYPE="A"
CFTTL=120
FORCE=false
CFFILE_PATH="$HOME/.cf"
WANIPSITE="http://v4.ipv6-test.com/api/myip.php"
NOW_DATE_TIME=$(date "+%Y-%m-%d %H:%M:%S")

# 函数：日志输出
log() {
    echo "$NOW_DATE_TIME $1"
}

# 函数：错误处理
error_exit() {
    log "错误：$1" >&2
    exit 1
}

# 解析命令行参数
while getopts ":k:e:h:z:t:f:p:" opts; do
    case ${opts} in
        k) CFAPI_KEY=${OPTARG} ;;
        e) CFAPI_EMAIL=${OPTARG} ;;
        h) CFRECORD_NAME=${OPTARG} ;;
        z) CFZONE_NAME=${OPTARG} ;;
        t) CFRECORD_TYPE=${OPTARG} ;;
        f) FORCE=${OPTARG} ;;
        p) CFFILE_PATH=${OPTARG} ;;
        :) error_exit "选项 -$OPTARG 需要参数。" ;;
        \?) error_exit "无效选项: -$OPTARG" ;;
    esac
done

# 检查必要参数
[[ -z "$CFAPI_KEY" ]] && error_exit "缺少API密钥，请使用-k参数提供"
[[ -z "$CFAPI_EMAIL" ]] && error_exit "缺少API邮箱，请使用-e参数提供"
[[ -z "$CFRECORD_NAME" ]] && error_exit "缺少主机名，请使用-h参数提供"
[[ -z "$CFZONE_NAME" ]] && error_exit "缺少域名，请使用-z参数提供"

# 根据记录类型设置IP获取网站
[[ "$CFRECORD_TYPE" == "AAAA" ]] && WANIPSITE="http://v6.ipv6-test.com/api/myip.php"

# 创建配置文件目录
mkdir -p "$CFFILE_PATH"

# 确保记录名是FQDN
[[ "$CFRECORD_NAME" != "$CFZONE_NAME" && -n "${CFRECORD_NAME##*$CFZONE_NAME}" ]] && CFRECORD_NAME="$CFRECORD_NAME.$CFZONE_NAME"

# 获取当前WAN IP
WAN_IP=$(curl -s ${WANIPSITE})
WAN_IP_FILE="$CFFILE_PATH/.cf-wan_ip_$CFRECORD_NAME.txt"
OLD_WAN_IP=$(cat "$WAN_IP_FILE" 2>/dev/null || echo "")

# 如果IP未变更且未强制更新，退出脚本
if [[ "$WAN_IP" == "$OLD_WAN_IP" && "$FORCE" != true ]]; then
    log "IP未变更，无需更新。如需强制更新，请使用 -f true 参数。"
    exit 0
fi

# 获取zone_identifier和record_identifier
ID_FILE="$CFFILE_PATH/.cf-id_$CFRECORD_NAME.txt"
if [[ -f $ID_FILE && $(wc -l < "$ID_FILE") == 4 && 
      "$(sed -n '3p' "$ID_FILE")" == "$CFZONE_NAME" && 
      "$(sed -n '4p' "$ID_FILE")" == "$CFRECORD_NAME" ]]; then
    CFZONE_ID=$(sed -n '1p' "$ID_FILE")
    CFRECORD_ID=$(sed -n '2p' "$ID_FILE")
    log "从缓存文件读取到 CFZONE_ID: $CFZONE_ID, CFRECORD_ID: $CFRECORD_ID"
else
    log "正在获取Cloudflare区域ID和记录ID..."
    ZONE_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$CFZONE_NAME" \
                    -H "X-Auth-Email: $CFAPI_EMAIL" \
                    -H "X-Auth-Key: $CFAPI_KEY" \
                    -H "Content-Type: application/json")
    
    CFZONE_ID=$(echo "$ZONE_RESPONSE" | jq -r '.result[0].id')
    [[ -z "$CFZONE_ID" ]] && error_exit "无法获取区域ID。请检查您的域名和API凭证是否正确。"
    
    RECORD_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?type=$CFRECORD_TYPE&name=$CFRECORD_NAME" \
                      -H "X-Auth-Email: $CFAPI_EMAIL" \
                      -H "X-Auth-Key: $CFAPI_KEY" \
                      -H "Content-Type: application/json")
    
    CFRECORD_ID=$(echo "$RECORD_RESPONSE" | jq -r '.result[0].id')
    [[ -z "$CFRECORD_ID" ]] && error_exit "无法获取记录ID。请检查您的记录名称是否正确。"
    
    printf "%s\n%s\n%s\n%s\n" "$CFZONE_ID" "$CFRECORD_ID" "$CFZONE_NAME" "$CFRECORD_NAME" > "$ID_FILE"
    log "ID信息已保存到缓存文件"
fi

log "正在更新DNS记录 $CFRECORD_NAME 到 $WAN_IP"

# 发送更新请求到Cloudflare API
RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records/$CFRECORD_ID" \
  -H "X-Auth-Email: $CFAPI_EMAIL" \
  -H "X-Auth-Key: $CFAPI_KEY" \
  -H "Content-Type: application/json" \
  --data "{\"type\":\"$CFRECORD_TYPE\",\"name\":\"$CFRECORD_NAME\",\"content\":\"$WAN_IP\",\"ttl\":$CFTTL}")

# 检查更新是否成功
if [[ "$(echo "$RESPONSE" | jq -r '.success')" == "true" ]]; then
    log "DNS记录更新成功！"
    echo "$WAN_IP" > "$WAN_IP_FILE"
else
    log "DNS记录更新失败"
    log "API响应: $RESPONSE"
    exit 1
fi
