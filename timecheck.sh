#!/bin/bash
# ----------------------------------------------------------
#  跨发行版时区 & 时间同步一键初始化
#  支持 Debian/Ubuntu/CentOS/RHEL/Rocky/Alma
# ----------------------------------------------------------
set -euo pipefail

TZ="Asia/Shanghai"

# 1. 检测发行版
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "无法识别系统" >&2; exit 1
fi

# 2. 设置时区（所有系统通用）
if [ -f /usr/bin/timedatectl ]; then
    timedatectl set-timezone "$TZ"
else
    # 极简系统（容器）无 timedatectl
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
    echo "$TZ" > /etc/timezone
fi
echo "==> 时区已设为 $TZ"

# 3. 安装并启动时间同步服务
case "$OS" in
    ubuntu|debian)
        # Debian/Ubuntu 新系统推荐 chrony
        apt-get update -qq
        apt-get install -y chrony sudo
        systemctl enable --now chrony
        echo "==> Debian/Ubuntu：已安装并启动 chrony"
        ;;
    centos|rhel|rocky|almalinux)
        # CentOS 7 默认无 chrony，8+ 默认有
        if command -v dnf &>/dev/null; then
            dnf install -y chrony sudo
        else
            yum install -y chrony sudo
        fi
        systemctl enable --now chronyd
        echo "==> CentOS/RHEL：已安装并启动 chronyd"
        ;;
    *)
        echo "未支持系统：$OS" >&2; exit 1
        ;;
esac

# 4. 立即强制同步一次
if systemctl is-active chronyd &>/dev/null; then
    chronyc -a makestep   # 立即步进同步
elif systemctl is-active chrony &>/dev/null; then
    chronyc -a makestep
else
    # 极简 fallback：ntpdate（若存在）
    if command -v ntpdate &>/dev/null; then
        ntpdate -u pool.ntp.org
    fi
fi
echo "==> 时间已强制同步完成"

# 5. 查看状态
timedatectl status