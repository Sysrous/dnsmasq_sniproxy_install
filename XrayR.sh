#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误: ${plain} 必须使用root用户运行此脚本！\n" && exit 1

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

check_enabled() {
    temp=$(systemctl is-enabled XrayR)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_install() {
    if [[ ! -f /usr/local/XrayR/XrayR ]]; then
        echo -e "${red}请先安装XrayR${plain}"
        exit 1
    fi
    return 0
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "XrayR状态: ${green}已运行${plain}"
            ;;
        1)
            echo -e "XrayR状态: ${yellow}未运行${plain}"
            ;;
        2)
            echo -e "XrayR状态: ${red}未安装${plain}"
    esac
}

start() {
    check_install
    systemctl start XrayR
    sleep 1
    show_status
}

stop() {
    check_install
    systemctl stop XrayR
    sleep 1
    show_status
}

restart() {
    check_install
    systemctl restart XrayR
    sleep 1
    show_status
}

show_log() {
    check_install
    journalctl -u XrayR.service -e --no-pager -f
}

config() {
    check_install
    vi /etc/XrayR/config.yml
    restart
}

update() {
    bash <(curl -Ls https://raw.githubusercontent.com/Sysrous/dnsmasq_sniproxy_install/refs/heads/master/install.sh)
}

uninstall() {
    check_install
    systemctl stop XrayR
    systemctl disable XrayR
    rm /etc/systemd/system/XrayR.service -f
    systemctl daemon-reload
    rm /etc/XrayR/ -rf
    rm /usr/local/XrayR/ -rf
    rm /usr/bin/XrayR -f
    rm /usr/bin/xrayr -f
    echo -e "${green}卸载成功！${plain}"
}

show_menu() {
    echo -e "
  ${green}XrayR 后端管理脚本${plain}
---
  ${green}1.${plain} 启动 XrayR
  ${green}2.${plain} 停止 XrayR
  ${green}3.${plain} 重启 XrayR
---
  ${green}4.${plain} 修改配置
  ${green}5.${plain} 查看日志
---
  ${green}6.${plain} 更新 XrayR
  ${green}7.${plain} 卸载 XrayR
---
  ${green}0.${plain} 退出脚本
"
    show_status
    echo && read -p "请输入选择 [0-7]: " num

    case "${num}" in
        1) start ;;
        2) stop ;;
        3) restart ;;
        4) config ;;
        5) show_log ;;
        6) update ;;
        7) uninstall ;;
        0) exit 0 ;;
        *) echo -e "${red}请输入正确的数字 [0-7]${plain}" ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
        "start") start ;;
        "stop") stop ;;
        "restart") restart ;;
        "log") show_log ;;
        "config") config ;;
        "update") update ;;
        "uninstall") uninstall ;;
        *) echo "无效命令" ;;
    esac
else
    show_menu
fi
