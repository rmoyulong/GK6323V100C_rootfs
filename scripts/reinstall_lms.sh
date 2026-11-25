#!/bin/bash
set -e

echo "🛑 第一步：停止并强制卸载所有 LMS 相关服务..."
systemctl stop lyrionmusicserver 2>/dev/null || true
systemctl disable lyrionmusicserver 2>/dev/null || true
pkill -f squeezeboxserver 2>/dev/null || true

# 强制清除 dpkg 状态，即使报错也继续
dpkg --remove --force-remove-reinstreq lyrionmusicserver 2>/dev/null || true
dpkg --purge --force-all lyrionmusicserver 2>/dev/null || true
apt autoremove --purge -y 2>/dev/null || true

echo "🧹 第二步：深度清理所有残留文件（包括全局 Perl 模块）..."
# 删除程序目录
rm -rf /usr/share/squeezeboxserver
rm -rf /usr/share/perl5/Slim
rm -rf /usr/lib/perl5/Slim
# 删除配置和数据目录
rm -rf /etc/squeezeboxserver
rm -rf /var/lib/squeezeboxserver
rm -rf /var/log/squeezeboxserver
# 删除 systemd 配置
rm -f /etc/systemd/system/lyrionmusicserver.service
rm -rf /etc/systemd/system/lyrionmusicserver.service.d
# 重载系统守护进程
systemctl daemon-reload

echo "📦 第三步：安装基础依赖..."
apt update
apt install -y wget curl perl-base libio-socket-ssl-perl libcrypt-openssl-rsa-perl libnet-ssleay-perl libxml-parser-perl libgd-gd2-perl libdbd-sqlite3-perl lame flac faad sox libsox-fmt-all

echo "⬇️ 第四步：下载并安装最新 Lyrion Music Server (aarch64/arm64)..."

# 获取最新安装包链接 (如果官方源不稳定，可替换为固定版本链接)
echo ">>> 强制安装，覆盖任何冲突..."
# 强制安装，覆盖任何冲突
dpkg -i --force-overwrite ./lms_arm.deb
apt --fix-broken install -y

echo "✅ 第五步：验证安装并启动..."
# 检查关键文件是否存在
if [ -f "/usr/sbin/squeezeboxserver" ]; then
    echo "✨ 程序文件已就位。"
else
    echo "❌ 程序文件缺失，安装可能失败。"
    exit 1
fi

# 启动服务
systemctl enable lyrionmusicserver
systemctl start lyrionmusicserver

echo "⏳ 等待服务初始化 (10秒)..."
sleep 10

# 检查状态
if systemctl is-active --quiet lyrionmusicserver; then
    echo "🎉 成功！Lyrion Music Server 已启动。"
    echo "🌐 请访问: http://$(hostname -I | awk '{print $1}'):9000"
else
    echo "⚠️ 服务启动异常，查看日志:"
    journalctl -u lyrionmusicserver -n 20 --no-pager
fi
