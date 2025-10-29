#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# 检查root权限
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# 安装基础依赖
if command -v yum >/dev/null 2>&1; then
    yum install wget curl tar socat -y >/dev/null 2>&1
else
    apt update >/dev/null 2>&1
    apt install wget curl tar socat -y >/dev/null 2>&1
fi

# 1. 准备目录
echo -e "${green}正在准备安装目录...${plain}"
rm -rf /usr/local/XrayR
mkdir -p /usr/local/XrayR
cd /usr/local/XrayR

# 2. 下载后端程序和配置文件
echo -e "${green}正在下载后端程序及配置文件...${plain}"
wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR https://raw.githubusercontent.com/Sysrous/dnsmasq_sniproxy_install/refs/heads/master/xrayr
wget -q -N --no-check-certificate -O /usr/local/XrayR/config.yml https://raw.githubusercontent.com/Sysrous/dnsmasq_sniproxy_install/refs/heads/master/config.yml
wget -q -N --no-check-certificate -O /usr/local/XrayR/geoip.dat https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat
wget -q -N --no-check-certificate -O /usr/local/XrayR/geosite.dat https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat
chmod +x /usr/local/XrayR/XrayR

# 3. 下载并安装管理脚本
echo -e "${green}正在安装管理脚本...${plain}"
# 确保这里的文件名和您上传到 GitHub 的文件名一致！
wget -q -N --no-check-certificate -O /usr/bin/XrayR https://raw.githubusercontent.com/Sysrous/dnsmasq_sniproxy_install/refs/heads/master/XrayR.sh
chmod +x /usr/bin/XrayR

# 4. 创建快捷方式
ln -sf /usr/bin/XrayR /usr/bin/xrayr
echo -e "${green}管理脚本快捷方式 'xrayr' 创建成功。${plain}"

# 5. 安装 systemd 服务
echo -e "${green}正在安装 systemd 服务...${plain}"
rm -f /etc/systemd/system/XrayR.service
wget -q -N --no-check-certificate -O /etc/systemd/system/XrayR.service https://raw.githubusercontent.com/Sysrous/dnsmasq_sniproxy_install/refs/heads/master/XrayR.service

# 6. 复制配置文件并设置权限
mkdir -p /etc/XrayR
cp /usr/local/XrayR/config.yml /etc/XrayR/config.yml
cp /usr/local/XrayR/geoip.dat /etc/XrayR/geoip.dat
cp /usr/local/XrayR/geosite.dat /etc/XrayR/geosite.dat
chmod -R 777 /etc/XrayR

# 7. 设置服务并启动
systemctl daemon-reload
systemctl enable XrayR
systemctl start XrayR

echo -e "\n${green}=====================================================${plain}"
echo -e "${green} XrayR 安装成功！${plain}"
echo -e "${yellow}注意：服务已尝试启动，但首次安装通常会因配置为空而失败。${plain}"
echo -e " "
echo -e "您现在可以执行 ${green}xrayr${plain} 命令来管理后端。"
echo -e "请立即使用 ${green}xrayr config${plain} 命令修改配置文件！"
echo -e "${green}=====================================================${plain}"
