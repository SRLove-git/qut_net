#!/usr/bin/env bash
#
# QUT-POL 校园网自动连接与认证脚本
#   - 检测到 WiFi 断开时自动连接 QUT-POL
#   - 检测到未认证时自动完成 Dr.COM 校园网认证
#
# 用法:
#   ./qut-autologin.sh           # 前台循环运行（守护模式）
#   ./qut-autologin.sh --once    # 只检查/执行一次
#
# 依赖: nmcli (NetworkManager)、curl

set -u

# ============ 配置 ============
USERNAME=""      # 校园网账号
PASSWORD=""     # 校园网密码（末尾的 ? 是密码的一部分）
SSID="QUT-POL"               # WiFi 名称
PORTAL_HOST="net.qut.edu.cn" # Dr.COM 认证门户
CHECK_URL="http://www.baidu.com/"   # 用 HTTP 请求检测是否已认证
CHECK_INTERVAL=30            # 守护模式检查间隔（秒）
# 日志文件：root 运行时写到 /var/log，普通用户写到 home 目录
if [ "$(id -u)" = "0" ]; then
    LOG_FILE="/var/log/qut-autologin.log"
else
    LOG_FILE="${HOME}/.qut-autologin.log"
fi
# =============================

log() {
    local msg="[$(date '+%F %T')] $*"
    echo "$msg"
    if [ -n "${LOG_FILE:-}" ] && ( [ -w "${LOG_FILE}" ] || touch "$LOG_FILE" 2>/dev/null ); then
        echo "$msg" >> "$LOG_FILE" 2>/dev/null
    fi
}

# 获取无线网卡设备名
get_wifi_dev() {
    nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}'
}

# 确保 WiFi 已连接到 QUT-POL
ensure_wifi() {
    local dev
    dev=$(get_wifi_dev)
    [ -z "$dev" ] && { log "未找到无线网卡"; return 1; }

    local conn
    conn=$(nmcli -t -f DEVICE,CONNECTION device status 2>/dev/null | awk -F: -v d="$dev" '$1==d{print $2}')

    if [ "$conn" = "$SSID" ]; then
        return 0
    fi

    log "WiFi 未连接到 $SSID（当前: ${conn:-无}），尝试连接..."
    nmcli radio wifi on 2>/dev/null

    # 优先激活已保存的连接，失败则用 SSID 直连
    nmcli connection up "$SSID" 2>/dev/null || \
    nmcli device wifi connect "$SSID" 2>/dev/null || \
    nmcli device wifi connect "$SSID" password "" 2>/dev/null

    # 等待 DHCP 分配 IP
    sleep 6
    conn=$(nmcli -t -f DEVICE,CONNECTION device status 2>/dev/null | awk -F: -v d="$dev" '$1==d{print $2}')
    if [ "$conn" = "$SSID" ]; then
        log "WiFi 已连接到 $SSID"
        return 0
    fi
    log "WiFi 连接失败"
    return 1
}

# 判断网络是否已认证（能正常上网）
# 返回 0 表示已认证，1 表示未认证/无网络
is_online() {
    local redirect code
    redirect=$(curl -s -m 6 -o /dev/null -w '%{redirect_url}' "$CHECK_URL" 2>/dev/null)
    # 未认证时，任意 HTTP 请求会被重定向到认证门户
    case "$redirect" in
        *"$PORTAL_HOST"*|*10.20.10.11*) return 1 ;;
    esac

    code=$(curl -s -m 6 -o /dev/null -w '%{http_code}' "$CHECK_URL" 2>/dev/null)
    case "$code" in
        200|301|302) return 0 ;;
        *) return 1 ;;
    esac
}

# 执行 Dr.COM 校园网认证
# 返回 0 表示成功
do_login() {
    local resp
    resp=$(curl -s -m 10 -G "http://${PORTAL_HOST}/drcom/login" \
        --data-urlencode "callback=dr1" \
        --data-urlencode "DDDDD=${USERNAME}" \
        --data-urlencode "upass=${PASSWORD}" \
        --data-urlencode "0MKKey=123456" \
        --data-urlencode "R1=0" \
        --data-urlencode "R2=" \
        --data-urlencode "R3=0" \
        --data-urlencode "R6=0" \
        --data-urlencode "para=00" \
        --data-urlencode "v6ip=" \
        --data-urlencode "terminal_type=1" \
        --data-urlencode "lang=zh-cn" \
        --data-urlencode "jsVersion=4.X" \
        2>/dev/null)

    if echo "$resp" | grep -q '"result":1'; then
        log "校园网认证成功"
        return 0
    fi

    # 提取错误信息（便于排查）
    local err
    err=$(echo "$resp" | grep -oE '"msga":"[^"]*"|"error_prompt_zh":"[^"]*"' | head -1)
    log "校园网认证失败 ${err}"
    return 1
}

# 单次检查与处理
run_once() {
    ensure_wifi || return 1

    if is_online; then
        log "网络正常，无需处理"
        return 0
    fi

    log "检测到网络未认证，开始校园网认证..."
    local i
    for i in 1 2 3; do
        if do_login; then
            sleep 3
            is_online && return 0
            log "认证接口返回成功，等待网络生效..."
            sleep 5
        else
            sleep 5
        fi
    done
    log "本次认证未成功，将在下个周期重试"
    return 1
}

# ============ 入口 ============
if [ "${1:-}" = "--once" ]; then
    run_once
    exit $?
fi

log "QUT-POL 自动联网守护启动（每 ${CHECK_INTERVAL}s 检查一次）"
while true; do
    run_once
    sleep "$CHECK_INTERVAL"
done
