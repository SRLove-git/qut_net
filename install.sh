#!/usr/bin/env bash
#
# QUT-POL 校园网自动认证 一键安装脚本
# 用法: sudo bash install.sh
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/qut-autologin.sh"
SERVICE_PATH="/etc/systemd/system/qut-autologin.service"

if [ "$(id -u)" != "0" ]; then
    echo "请使用 root 运行: sudo bash install.sh"
    exit 1
fi

command -v nmcli >/dev/null || { echo "缺少依赖 nmcli（NetworkManager）"; exit 1; }
command -v curl  >/dev/null || { echo "缺少依赖 curl"; exit 1; }

chmod +x "$SCRIPT_PATH"

# 生成 systemd 服务文件（写入脚本实际路径）
sed "s|__SCRIPT_PATH__|$SCRIPT_PATH|g" "$SCRIPT_DIR/qut-autologin.service" > "$SERVICE_PATH"

systemctl daemon-reload
systemctl enable --now qut-autologin.service

echo "======================================"
echo " 安装完成！"
echo " 脚本: $SCRIPT_PATH"
echo " 服务: $SERVICE_PATH"
echo " 日志: /var/log/qut-autologin.log"
echo "======================================"
echo " 修改账号密码请编辑脚本顶部配置，然后执行:"
echo "   systemctl restart qut-autologin"
echo ""
echo " 常用命令:"
echo "   systemctl status   qut-autologin   # 查看状态"
echo "   systemctl restart  qut-autologin   # 重启"
echo "   journalctl -u qut-autologin -f     # 实时日志"
