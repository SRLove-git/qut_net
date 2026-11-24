# QUT-POL 校园网自动连接与认证

针对 **青岛理工大学（QUT）校园网 QUT-POL** 的自动联网脚本：

- 检测到 WiFi 断开时，自动重新连接 `QUT-POL`
- 检测到未认证（被门户拦截）时，自动完成 **Dr.COM 网页认证**
- 以 systemd 服务方式常驻运行，**开机自启**，掉线自动恢复

## 原理

`QUT-POL` 是开放式 WiFi，连上后需要通过 Dr.COM 网页门户认证才能真正上网。认证门户为 `net.qut.edu.cn`（10.20.10.11）。

登录接口：

```
GET http://net.qut.edu.cn/drcom/login
参数:
  DDDDD      = 校园网账号
  upass      = 校园网密码
  0MKKey     = 123456
  R1=0  R2=(空)  R3=0  R6=0  para=00  v6ip=
  terminal_type=1  lang=zh-cn  jsVersion=4.X
```

> ⚠️ 关键点：`R2` 必须为**空值**。若误传 `R2=0`，服务端会把密码按 MD5 校验，导致报「密码错误」。

认证状态通过一个 HTTP 请求判断：

- 已认证：`http://www.baidu.com/` 返回 `200`（或正常跳转 https）
- 未认证：被 `302` 重定向到门户 `http://10.20.10.11/...`

## 目录结构

```
qut-autologin/
├── qut-autologin.sh      # 主脚本（账号/密码在文件顶部配置）
├── qut-autologin.service # systemd 服务模板
├── install.sh            # 一键安装脚本
└── README.md
```

## 安装

```bash
# 1. 编辑 qut-autologin.sh 顶部，填入账号密码
vim qut-autologin.sh

# 2. 一键安装（自动注册 systemd 服务并开机自启）
sudo bash install.sh
```

## 手动运行

```bash
./qut-autologin.sh --once     # 只检查/执行一次
./qut-autologin.sh            # 前台循环守护
```

## 常用命令

```bash
systemctl status   qut-autologin          # 查看状态
systemctl restart  qut-autologin          # 重启
systemctl stop     qut-autologin          # 停止
journalctl -u qut-autologin -f            # 实时日志
tail -f /var/log/qut-autologin.log        # 日志文件（root 运行时）
```

## 依赖

- `nmcli`（NetworkManager）
- `curl`

## 配置项

`qut-autologin.sh` 顶部：

| 变量 | 说明 |
|------|------|
| `USERNAME` | 校园网账号 |
| `PASSWORD` | 校园网密码 |
| `SSID` | WiFi 名称（默认 `QUT-POL`） |
| `PORTAL_HOST` | 认证门户（默认 `net.qut.edu.cn`） |
| `CHECK_URL` | 在线检测地址 |
| `CHECK_INTERVAL` | 守护模式检查间隔（秒，默认 30） |

## 免责声明

本项目仅用于个人设备自动联网，请遵守校园网使用规定，勿用于任何违规用途。
