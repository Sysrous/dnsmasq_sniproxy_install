#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl tar crontabs socat -y >/dev/null 2>&1
    else
        apt update -y
        apt install wget curl tar cron socat -y >/dev/null 2>&1
    fi
}

check_status() {
    if [[ ! -f /etc/systemd/system/XrayR.service ]]; then
        return 2
    fi
    temp=$(systemctl status XrayR | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_XrayR() {
    # 1. 准备目录
    rm -rf /usr/local/XrayR/
    mkdir -p /usr/local/XrayR/
	cd /usr/local/XrayR/

    # 2. 下载所有组件
    echo -e "${green}开始下载 XrayR 组件...${plain}"
    wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR https://raw.githubusercontent.com/Sysrous/dnsmasq_sniproxy_install/refs/heads/master/xrayr
    wget -q -N --no-check-certificate -O /usr/local/XrayR/config.yml https://raw.githubusercontent.com/Sysrous/dnsmasq_sniproxy_install/refs/heads/master/config.yml
    wget -q -N --no-check-certificate -O /usr/local/XrayR/dns.json https://raw.githubusercontent.com/Sysrous/dnsmasq_sniproxy_install/refs/heads/master/dns.json
    wget -q -N --no-check-certificate -O /usr/local/XrayR/route.json https://raw.githubusercontent.com/Sysrous/dnsmasq_sniproxy_install/refs/heads/master/route.json
    wget -q -N --no-check-certificate -O /usr/local/XrayR/geoip.dat https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat
    wget -q -N --no-check-certificate -O /usr/local/XrayR/geosite.dat https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat
    chmod +x XrayR

    # 3. 强制覆盖安装 systemd 服务文件 (来自您的 GitHub)
    echo -e "${green}正在从您的 GitHub 链接安装/覆盖 systemd 服务...${plain}"
    rm -f /etc/systemd/system/XrayR.service
    wget -q -N --no-check-certificate -O /etc/systemd/system/XrayR.service https://raw.githubusercontent.com/Sysrous/dnsmasq_sniproxy_install/refs/heads/master/XrayR.service
    
    # 4. 安装管理脚本
    curl -o /usr/bin/XrayR -Ls https://raw.githubusercontent.com/Sysrous/dnsmasq_sniproxy_install/refs/heads/master/xrayr
    chmod +x /usr/bin/XrayR
    ln -sf /usr/bin/XrayR /usr/bin/xrayr

    # 5. 处理配置文件
    mkdir -p /etc/XrayR/
    if [[ ! -f /etc/XrayR/config.yml ]]; then
        cp config.yml /etc/XrayR/config.yml
    fi
    cp dns.json /etc/XrayR/dns.json
    cp route.json /etc/XrayR/route.json
    cp geoip.dat /etc/XrayR/geoip.dat
    cp geosite.dat /etc/XrayR/geosite.dat

    # 6. 设置 777 权限
    chmod -R 777 /etc/XrayR/
    
    # 7. 重载并启用服务
    systemctl daemon-reload
    systemctl enable XrayR
    echo -e "${green}XrayR 安装完成，已设置开机自启。${plain}"

    # 8. 立即尝试启动服务
    echo -e "${green}正在尝试启动 XrayR 服务...${plain}"
    systemctl start XrayR
    sleep 2

    # 9. 检查状态并给出最终提示
    check_status
    if [[ $? == 0 ]]; then
        echo -e "\n${green}成功！${plain} XrayR 安装并启动成功！"
    else
        echo -e "\n${red}需要您操作！${plain} XrayR 已安装，但服务启动失败。 ${yellow}（首次安装属正常现象）${plain}"
        echo -e "请立即编辑配置文件: ${green}vi /etc/XrayR/config.yml${plain}"
        echo -e "修改保存后，请执行: ${green}XrayR restart${plain}"
    fi
    
    # 10. 清理
    cd $cur_dir
    rm -f install.sh
}

# --- Main ---
echo -e "${green}正在准备安装环境...${plain}"
install_base
install_XrayR
