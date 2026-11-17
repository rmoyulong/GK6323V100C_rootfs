#!/bin/bash
# 从运行中的内核提取配置并补USB音频支持（在盒子上执行后传回编译机即可）
set -e

echo "=== 提取当前运行内核配置 ==="
if [ -f /proc/config.gz ]; then
    zcat /proc/config.gz > running.config
    echo "成功从/proc/config.gz提取配置"
elif [ -f /boot/config-$(uname -r) ]; then
    cp /boot/config-$(uname -r) running.config
    echo "成功从/boot提取配置"
else
    echo "未找到内核配置，请从原内核镜像中提取"
    exit 1
fi

echo "=== 追加USB音频配置 ==="
cat >> running.config << EOF
# USB 声卡支持
CONFIG_SOUND=y
CONFIG_SND=y
CONFIG_SND_HRTIMER=y
CONFIG_SND_SEQUENCER=y
CONFIG_SND_SEQUENCER_HRTIMER=y
CONFIG_SND_USB_AUDIO=m
CONFIG_SND_USB_AUDIO_USE_MEDIA_CONTROLLER=y
CONFIG_USB_AUDIO_CLASS_1=y
CONFIG_SND_PROC_FS=y
CONFIG_SND_CTL_FSMAP=y
CONFIG_SND_PCM_TIMER=y
CONFIG_MODULES=y
CONFIG_MODULE_UNLOAD=y
EOF

echo ""
echo "=== 完成，生成的 running.config 可直接用于编译 ==="
echo "文件大小: $(ls -lh running.config | awk '{print $5}')"
echo "请将本文件拷贝到编译机，替换build.sh中的defconfig步骤，直接make即可"
