#!/usr/bin/env bash
#
# QUT-POL 校园网自动认证 一键安装脚本
# 用法: sudo bash install.sh
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/qut-autologin.sh"
SERVICE_PATH="/etc/systemd/system/qut-autologin.service"
CONFIG_FILE="/etc/qut-autologin.conf"

if [ "$(id -u)" != "0" ]; then
    echo "请使用 root 运行: sudo bash install.sh"
    exit 1
fi

command -v nmcli >/dev/null || { echo "缺少依赖 nmcli（NetworkManager）"; exit 1; }
command -v curl  >/dev/null || { echo "缺少依赖 curl"; exit 1; }

chmod +x "$SCRIPT_PATH"

# 生成凭据配置文件（如不存在），权限 600，避免明文泄露
if [ ! -f "$CONFIG_FILE" ]; then
    cp "$SCRIPT_DIR/qut-autologin.conf.example" "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    echo "已生成配置文件: $CONFIG_FILE"
fi

# 生成 systemd 服务文件（写入脚本实际路径）
sed "s|__SCRIPT_PATH__|$SCRIPT_PATH|g" "$SCRIPT_DIR/qut-autologin.service" > "$SERVICE_PATH"

systemctl daemon-reload

# 检查账号/密码是否已填写，未填写则只安装不启动
creds_configured() {
    # shellcheck disable=SC1090
    . "$CONFIG_FILE" 2>/dev/null
    [ -n "${USERNAME:-}" ] && [ -n "${PASSWORD:-}" ]
}

echo "======================================"
echo " 安装完成！"
echo " 脚本: $SCRIPT_PATH"
echo " 配置: $CONFIG_FILE"
echo " 服务: $SERVICE_PATH"
echo " 日志: /var/log/qut-autologin.log"
echo "======================================"

if creds_configured; then
    systemctl enable --now qut-autologin.service
    echo " 凭据已配置，服务已启动。"
else
    echo " 尚未配置账号/密码，请先编辑配置文件:"
    echo "   sudo vim $CONFIG_FILE"
    echo ""
    echo " 填写完成后启用并启动服务:"
    echo "   sudo systemctl enable --now qut-autologin"
fi

echo ""
echo " 修改账号密码请编辑 $CONFIG_FILE，然后执行:"
echo "   systemctl restart qut-autologin"
echo ""
echo " 常用命令:"
echo "   systemctl status   qut-autologin   # 查看状态"
echo "   systemctl restart  qut-autologin   # 重启"
echo "   journalctl -u qut-autologin -f     # 实时日志"
