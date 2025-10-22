#!/bin/bash
#====================================================
# 名称: unbound-forward-interactive.sh
# 功能: 交互式配置 unbound 转发到非标端口 DNS（带默认值）
# 用法: sudo ./unbound-forward-interactive.sh
# 系统: Debian / Ubuntu
#====================================================

set -e  # 出错停止

# =============== 默认值设置 ===============
DEFAULT_UPSTREAM_IP="8.8.8.8"
DEFAULT_UPSTREAM_PORT="5353"
UNBOUND_CONF="/etc/unbound/unbound.conf.d/forward-to-custom-dns.conf"
LISTEN_ADDRESS="127.0.0.1"
CACHE_SIZE="4m"

# =============== 输入函数 ===============
input_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    local input

    while true; do
        printf "%s [%s]: " "$prompt" "$default"
        read -r input

        # 使用默认值
        if [ -z "$input" ]; then
            eval "$var_name='$default'"
            break
        fi

        # 检查是否为 ip:port 格式
        if [[ "$input" == *:* ]] && [[ "$input" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}:.* ]]; then
            UP="${input%%:*}"
            PT="${input##*:}"
            if valid_ip "$UP" && valid_port "$PT"; then
                eval "$var_name"="'$input'"
                break
            else
                echo "❌ 输入无效，请重新输入。"
            fi
        elif [[ "$input" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
            eval "$var_name='$input'"
            break
        else
            echo "❌ 不是有效的 IP 地址或格式，请重新输入。"
        fi
    done
}

valid_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
        for seg in ${ip//./ }; do
            if [ "$seg" -gt 255 ] 2>/dev/null; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

valid_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]
}

# =============== 开始交互 ===============
echo "💬 欢迎使用 unbound 非标端口 DNS 转发配置工具"
echo "💡 提示：直接回车将使用方括号内的默认值"

# 输入上游 IP 或 IP:PORT
UPSTREAM_SPEC=""
input_with_default "请输入上游 DNS 服务器 IP" "$DEFAULT_UPSTREAM_IP" "UPSTREAM_SPEC"

# 如果输入包含冒号，则拆分
if [[ "$UPSTREAM_SPEC" == *:* ]]; then
    UPSTREAM_IP="${UPSTREAM_SPEC%%:*}"
    UPSTREAM_PORT="${UPSTREAM_SPEC##*:}"
else
    UPSTREAM_IP="$UPSTREAM_SPEC"
    # 单独输入端口
    while true; do
        printf "请输入上游端口 [%s]: " "$DEFAULT_UPSTREAM_PORT"
        read -r port_input
        UPSTREAM_PORT="${port_input:-$DEFAULT_UPSTREAM_PORT}"
        if valid_port "$UPSTREAM_PORT"; then
            break
        else
            echo "❌ 端口必须是 1-65535 之间的数字，请重试。"
        fi
    done
fi

# 再次确认
echo
echo "✅ 配置摘要："
echo "   上游 DNS: $UPSTREAM_IP:$UPSTREAM_PORT"
echo

while true; do
    printf "是否确认开始配置？[Y/n]: "
    read -r confirm
    confirm="${confirm:-y}"
    case "${confirm,,}" in
        y|yes) break ;;
        n|no) echo "🛑 已取消。"; exit 0 ;;
        *) echo "请输入 y 或 n" ;;
    esac
done

# =============== 安装与配置 unbound ===============
echo
echo "🔄 正在配置 unbound 转发至 ${UPSTREAM_IP}:${UPSTREAM_PORT}..."

# 安装 unbound
if ! command -v unbound &> /dev/null; then
    echo "📦 安装 unbound..."
    apt update && apt install -y unbound
else
    echo "✅ unbound 已安装"
fi

# 创建配置目录
mkdir -p /etc/unbound/unbound.conf.d

# 写入配置文件
cat << EOF > "$UNBOUND_CONF"
# 由交互式脚本生成：${UPSTREAM_IP}:${UPSTREAM_PORT}
server:
    interface: ${LISTEN_ADDRESS}
    port: 53
    do-ip4: yes
    do-udp: yes
    do-tcp: yes
    do-not-query-localhost: no
    access-control: ${LISTEN_ADDRESS} allow
    msg-cache-size: ${CACHE_SIZE}
    rrset-cache-size: ${CACHE_SIZE}

stub-zone:
    name: "."
    stub-addr: ${UPSTREAM_IP}@${UPSTEM_PORT}
EOF

# 使用 sudo 保存配置（需要权限）
sudo mv "$UNBOUND_CONF" "/etc/unbound/unbound.conf.d/"
UNBOUND_CONF="/etc/unbound/unbound.conf.d/$(basename "$UNBOUND_CONF")"

echo "📝 配置已写入: $UNBOUND_CONF"

# 停止 systemd-resolved（避免占用 53 端口）
if systemctl is-active --quiet systemd-resolved; then
    echo "⚠️ 停止 systemd-resolved..."
    sudo systemctl stop systemd-resolved
    sudo systemctl disable systemd-resolved || true
fi

# 启动 unbound
echo "🚀 启动 unbound 服务..."
sudo systemctl stop unbound || true
sudo systemctl enable unbound
sudo systemctl start unbound

sleep 3

# 检查状态
if ! systemctl is-active --quiet unbound; then
    echo "❌ unbound 启动失败！请查看日志：journalctl -u unbound -n 50"
    exit 1
fi

# 修改 resolv.conf
echo "🔧 设置 /etc/resolv.conf 使用 127.0.0.1"
echo -e "nameserver 127.0.0.1\noptions edns0" | sudo tee /etc/resolv.conf > /dev/null

# 测试连接
echo "🔍 测试 DNS 解析..."
if timeout 5 host google.com 127.0.0.1 >/dev/null 2>&1; then
    echo "🎉 成功！DNS 解析正常"
else
    echo "⚠️  警告：无法解析 google.com，请检查上游服务器是否可达"
fi

# 最终提示
cat << 'EOF'

✅ 配置完成！
--------------------------------------------------
所有 DNS 请求将通过 unbound 转发至：
    🌐  ${UPSTREAM_IP}:${UPSTREAM_PORT}

本机使用：
    🔹 127.0.0.1

📌 如需卸载，请运行：
      sudo rm '$UNBOUND_CONF'
      sudo systemctl restart systemd-resolved
      echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf

👋 感谢使用！
EOF
