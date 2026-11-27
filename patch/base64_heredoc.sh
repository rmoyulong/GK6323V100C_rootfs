#加 noecho 后的函数如下（支持 noecho / raw / strip 组合）：

#*****************************************************************************
#base64_heredoc list_src	取变量值 → 展开 $VAR → 去行首空格/Tab → 编码
#base64_heredoc list_src noecho	取变量值 → 保留 $VAR 字面量 → 去行首空格/Tab → 编码
#base64_heredoc list_src raw	取变量值 → 展开 → 保留缩进 → 编码
#base64_heredoc list_src raw noecho	取变量值 → 保留 $VAR → 保留缩进 → 编码
#*****************************************************************************

#*****************************************************************************
#两个关键限制
#noecho 要配单引号赋值  #这是 shell 机制决定的，函数无法逆转已展开的变量。

#list_src='... $HOME ...'（单引号）→ 变量里存的是字面 $HOME，noecho 才保留得住 ✅

#list_src="... $HOME ..."（双引号）→ 赋值时 $HOME 就被展开了，函数再 noecho 也无法恢复 ❌
#*****************************************************************************

#@@@@@@@@@@@@@@@@@@@@@@@调用的限制和正确运用@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
#1. 宿主侧 source（chroot 外使用）
#source "${{ github.workspace }}/patch/base64_heredoc.sh
#b64=$(base64_heredoc list_src)
#-----------------------------------
#2.在chroot外先把patch拷贝到挂载目录 /mnt/armbian_root 里面
#sudo mkdir -p /mnt/armbian_root/tmp/patch
#sudo cp -a "${{ github.workspace }}/patch/." /mnt/armbian_root/tmp/patch/
#2. chroot 内脚本顶部 source（chroot 内使用）
#source /tmp/patch/base64_heredoc.sh   # 注意：chroot 内的绝对路径
#之后在 chroot 脚本里就能正常调用： list_src 是变量名 不要加$
#b64=$(base64_heredoc list_src)
#echo "$b64" | base64 -d | tee /etc/apt/sources.list > /dev/null
#@@@@@@@@@@@@@@@@@@@@@@@调用的限制和正确运用结束@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

base64_heredoc() {
    local arg="$1"
    local opt="${*:2}"          # 合并后续所有参数，支持 "raw noecho" 等组合
    local content

    # 参数是已定义变量名 → 取变量值；否则当作字面内容
    if [[ "$arg" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] && declare -p "$arg" &>/dev/null; then
        content="${!arg}"
    else
        content="$arg"
    fi

    # 不含 noecho → 展开变量；含 noecho → 保留 $VAR 字面量
    if [[ "$opt" != *noecho* ]]; then
        content=$(eval "printf '%s' \"$content\"")
    fi

    # raw 保留缩进；默认去掉行首空格和 Tab
    if [[ "$opt" == *raw* ]]; then
        printf '%s' "$content" | base64 | tr -d '\n'
    else
        printf '%s' "$content" | sed 's/^[[:blank:]]*//' | base64 | tr -d '\n'
    fi
    printf '\n'
}

##########################设置需要base64的字符串变量##############################

# 阿里云 Debian 11 (bullseye) 存档源 /etc/apt/sources.list
list_src_apt='
deb http://mirrors.aliyun.com/debian-archive/debian bullseye main contrib non-free
deb-src http://mirrors.aliyun.com/debian-archive/debian bullseye main contrib non-free

deb http://mirrors.aliyun.com/debian-archive/debian-security bullseye-security main contrib non-free
deb-src http://mirrors.aliyun.com/debian-archive/debian-security bullseye-security main contrib non-free

deb http://mirrors.aliyun.com/debian-archive/debian bullseye-updates main contrib non-free
deb-src http://mirrors.aliyun.com/debian-archive/debian bullseye-updates main contrib non-free
'

# banner  /etc/update-motd.d/95-cats-banner
read -r -d '' list_src_banner <<'EOF' || true
#!/bin/bash
set -o pipefail
cat /etc/cats_banner
EOF

#把zarm改成zstd压缩方式 /etc/default/armbian-zram-config
read -r -d '' list_src_zarm <<'EOF' || true
            ENABLED=true
            ZRAM_PERCENTAGE=120
            MEM_LIMIT_PERCENTAGE=100
            ZRAM_MAX_DEVICES=4
            SWAP_ALGORITHM=zstd
EOF

# LMS 高解析度音乐异步推流网络优化 /etc/sysctl.d/99-lms-network.conf
read -r -d '' list_src_LMS_network <<'EOF' || true
            # LMS 高解析度音乐异步推流网络优化
            net.core.somaxconn = 1024
            net.core.netdev_max_backlog = 5000
            net.core.rmem_max = 16777216
            net.core.wmem_max = 16777216
            net.ipv4.tcp_rmem = 4096 87380 16777216
            net.ipv4.tcp_wmem = 4096 65536 16777216
EOF

#设置zram的大小600M /etc/sysctl.d/97-zram-opt.conf
read -r -d '' list_src_zram_opt <<'EOF' || true
            vm.swappiness=150
            vm.watermark_boost_factor=0
            vm.watermark_scale_factor=125
            vm.page-cluster=0
EOF

#建立启动后仅运行一次的脚本 /etc/systemd/system/resize-once.service
read -r -d '' list_src_resize_once <<'EOF' || true
            [Unit]
            Description=One-time resize script
            After=local-fs.target			
            ConditionPathExists=/etc/resize.sh
			
            [Service]
            Type=oneshot
            ExecStart=/etc/resize.sh
            RemainAfterExit=no
			
            [Install]
            WantedBy=multi-user.target
EOF

#对rootfs扩容的sh  /etc/resize.sh
read -r -d '' list_src_resize_sh <<'EOF' || true
            #!/bin/bash
            set -uo pipefail
            [ -e /etc/sudo.conf ] && chown root:root /etc/sudo.conf
            [ -e /etc/sudoers ]   && chown root:root /etc/sudoers
            [ -d /etc/sudoers.d ] && chown -R root:root /etc/sudoers.d
            [ -e /usr/bin/sudo ]  && chown root:root /usr/bin/sudo
            [ -e /usr/bin/sudo ]  && chmod 4755 /usr/bin/sudo
            ROOT_PART=$(findmnt -n -o SOURCE /)
            resize2fs "$ROOT_PART"
            systemctl restart lyrionmusicserver 2>/dev/null
            systemctl disable resize-once.service 2>/dev/null
            rm -f /etc/systemd/system/resize-once.service
            rm -f /etc/resize.sh
            systemctl daemon-reload
EOF

#设置squeezelite的配置 /etc/default/squeezelite
read -r -d '' list_src_squeezelite <<'EOF' || true
            SL_NAME="Squeezelite"
            SL_SOUNDCARD="hw:1,0"
            SB_EXTRA_ARGS="-D dop -p 85 -b 2048:4096"
EOF

#设置squeezelite服务文件 /usr/lib/systemd/system/squeezelite.service 
read -r -d '' list_src_squeezelite_service <<'EOF' || true
[Unit]
Description=Squeezelite LMS player
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=
ExecStart=/usr/local/bin/squeezelite -o hw:1,0 -D dop -p 85 -b 2048:4096 -n Squeezelite

[Install]
WantedBy=multi-user.target
EOF

#设置armbian启动config /mnt/armbian_boot/extlinux/extlinux.conf
read -r -d '' list_src_extlinux <<'EOF' || true
LABEL Armbian
  LINUX /${KERNEL_FILE}
  INITRD /${INITRD_FILE}
  FDT /dtb/amlogic/meson-gxl-s905x-p212.dtb
  APPEND root=UUID=${ROOT_UUID} rootflags=data=writeback rw console=ttyAML0,115200n8 console=tty0 no_console_suspend consoleblank=0 fsck.fix=yes fsck.repair=yes net.ifnames=0
EOF

#设置armbian启动config /mnt/armbian_boot/extlinux/extlinux.conf  Armbian_24.5.0_amlogic_s905lb-r3300l_bullseye_6.1.81_server_2024.03.13.img
read -r -d '' list_src_uEnv <<'EOF' || true
LABEL Armbian
    LINUX=/zImage
    INITRD=/uInitrd
    FDT=/dtb/amlogic/meson-gxl-s905x-p212.dtb
    APPEND root=UUID=${ROOT_UUID} rootflags=data=writeback rw console=ttyAML0,115200n8 console=tty0 no_console_suspend consoleblank=0 fsck.fix=yes fsck.repair=yes net.ifnames=0 cma=32M
EOF