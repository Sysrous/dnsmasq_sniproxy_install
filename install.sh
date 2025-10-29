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

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt update -y
        apt install wget curl unzip tar cron socat -y
    fi
}

# 0: running, 1: not running, 2: not installed
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

install_acme() {
    curl https://get.acme.sh | sh
}

install_XrayR() {
    # 1. 清理和准备目录
    if [[ -e /usr/local/XrayR/ ]]; then
        rm /usr/local/XrayR/ -rf
    fi
    mkdir /usr/local/XrayR/ -p
	cd /usr/local/XrayR/

    # 2. 统一下载所有组件到 /usr/local/XrayR
    echo -e "开始下载 XrayR 组件..."
    wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR https://raw.githubusercontent.com/Sysrous/dnsmasq_sniproxy_install/refs/heads/master/xrayr
    wget -q -N --no-check-certificate -O /usr/local/XrayR/config.yml https://raw.githubusercontent.com/Sysrous/dnsmasq_sniproxy_install/refs/heads/master/config.yml
    wget -q -N --no-check-certificate -O /usr/local/XrayR/custom_inbound.json https://raw.githubusercontent.com/Sysrous/dnsmasq_sniproxy_install/refs/heads/master/custom_inbound.json
    wget -q -N --no-check-certificate -O /usr/local/XrayR/custom_outbound.json https://raw.githubusercontent.com/Sysrous/dnsmasq_sniproxy_install/refs/heads/master/custom_outbound.json
    wget -q -N --no-check-certificate -O /usr/local/XrayR/dns.json https://raw.githubusercontent.com/Sysrous/dnsmasq_sniproxy_install/refs/heads/master/dns.json
    wget -q -N --no-check-certificate -O /usr/local/XrayR/route.json https://raw.githubusercontent.com/Sysrous/dnsmasq_sniproxy_install/refs/heads/master/route.json
    wget -q -N --no-check-certificate -O /usr/local/XrayR/geoip.dat https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat
    wget -q -N --no-check-certificate -O /usr/local/XrayR/geosite.dat https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat

    if [[ ! -f /usr/local/XrayR/XrayR ]]; then
        echo -e "${red}下载 XrayR 核心失败，请确保你的服务器能够下载 Github 的文件${plain}"
        exit 1
    fi
    chmod +x XrayR

    # 3. 安装 systemd 服务文件
    rm /etc/systemd/system/XrayR.service -f
    wget -q -N --no-check-certificate -O /etc/systemd/system/XrayR.service https://raw.githubusercontent.com/Sysrous/dnsmasq_sniproxy_install/refs/heads/master/XrayR.service
    
    # 4. 安装管理脚本
    curl -o /usr/bin/XrayR -Ls https://raw.githubusercontent.com/Sysrous/dnsmasq_sniproxy_install/refs/heads/master/xrayr
    chmod +x /usr/bin/XrayR
    ln -sf /usr/bin/XrayR /usr/bin/xrayr # 小写兼容，-sf 强制覆盖
    chmod +x /usr/bin/xrayr
    
    # 5. 处理配置文件
    mkdir /etc/XrayR/ -p
    
    # 区分全新安装和更新
    is_new_install=0
    if [[ ! -f /etc/XrayR/config.yml ]]; then
        is_new_install=1
        echo -e "检测到为全新安装，将复制预设配置文件..."
        cp config.yml /etc/XrayR/config.yml
    fi

    # 按需复制其他配置文件 (如果不存在)
    if [[ ! -f /etc/XrayR/dns.json ]]; then cp dns.json /etc/XrayR/dns.json; fi
    if [[ ! -f /etc/XrayR/route.json ]]; then cp route.json /etc/XrayR/route.json; fi
    if [[ ! -f /etc/XrayR/custom_inbound.json ]]; then cp custom_inbound.json /etc/XrayR/custom_inbound.json; fi
    if [[ ! -f /etc/XrayR/custom_outbound.json ]]; then cp custom_outbound.json /etc/XrayR/custom_outbound.json; fi
    
    # 强制更新 geoip 和 geosite 数据文件
    cp geoip.dat /etc/XrayR/geoip.dat
    cp geosite.dat /etc/XrayR/geosite.dat

    # 6. 设置您要求的 777 权限
    chmod -R 777 /etc/XrayR/
    echo -e "${yellow}警告：已根据您的要求为 /etc/XrayR/ 设置了 777 权限，请注意安全风险。${plain}"

    # 7. 重载服务并设置自启
    systemctl daemon-reload
    systemctl stop XrayR
    systemctl enable XrayR
    echo -e "${green}XrayR 安装/更新完成，已设置开机自启${plain}"

    # 8. 启动服务并检查状态
    if [[ ${is_new_install} -eq 1 ]]; then
        echo -e ""
        echo -e "${yellow}全新安装成功！请务必手动修改 /etc/XrayR/config.yml 配置文件后，再执行 XrayR start 来启动服务！${plain}"
    else
        systemctl start XrayR
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}XrayR 更新成功并已重启${plain}"
        else
            echo -e "${red}XrayR 可能启动失败，请使用 XrayR log 查看日志信息${plain}"
        fi
    fi

    # 9. 清理并显示用法
    cd $cur_dir
    rm -f install.sh
    echo -e ""
    echo "XrayR 管理脚本使用方法 (兼容使用xrayr执行，大小写不敏感): "
    echo "------------------------------------------"
    echo "XrayR                    - 显示管理菜单 (功能更多)"
    echo "XrayR start              - 启动 XrayR"
    echo "XrayR stop               - 停止 XrayR"
    echo "XrayR restart            - 重启 XrayR"
    echo "XrayR status             - 查看 XrayR 状态"
    echo "XrayR enable             - 设置 XrayR 开机自启"
    echo "XrayR disable            - 取消 XrayR 开机自启"
    echo "XrayR log                - 查看 XrayR 日志"
    echo "XrayR update             - 更新 XrayR"
    echo "XrayR config             - 修改配置文件"
    echo "XrayR install            - 安装 XrayR"
    echo "XrayR uninstall          - 卸载 XrayR"
    echo "XrayR version            - 查看 XrayR 版本"
    echo "------------------------------------------"
}

echo -e "${green}开始安装${plain}"
install_base
# install_acme
install_XrayR $1
