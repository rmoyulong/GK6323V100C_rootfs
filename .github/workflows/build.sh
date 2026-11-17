#!/bin/bash
set -e

# GK6323V100C (Hi3798MV310/MV320) 内核编译脚本
# 输出产物：uImage(含内置DTB) + 模块目录
# 参考 hi3798mv100 仓库编译流程
# 默认开启 USB 声卡支持

# 配置参数
KERNEL_VERSION=6.18.46
PATCHES_BASE_SHA=7.4-rc2
ARCH=arm64
CROSS_COMPILE=aarch64-linux-gnu-
LOAD_ADDR=0x2000000
ENTRY_POINT=0x2000000
DTB_NAME=hi3798mv200h-skyworth-stb.dtb  # GK6323对应MV200H设备树
OUTPUT_DIR=./output

echo "=== GK6323V100C 内核编译开始 ==="
echo "目标版本: Linux $KERNEL_VERSION ARM64"
echo "加载地址: $LOAD_ADDR, 入口地址: $ENTRY_POINT"
echo "内置设备树: $DTB_NAME"

# 1. 准备源码
if [ ! -d "linux-$KERNEL_VERSION" ]; then
    echo "=== 下载主线内核 v$KERNEL_VERSION ==="
    wget -q https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KERNEL_VERSION.tar.xz
    tar xf linux-$KERNEL_VERSION.tar.xz
    rm linux-$KERNEL_VERSION.tar.xz
fi

cd linux-$KERNEL_VERSION

# 2. 应用海思主线补丁
if [ ! -f ".patches_applied" ]; then
    echo "=== 应用histb海思补丁 ==="
    if [ ! -d "../patches" ]; then
        git clone --depth=1 https://github.com/histb-mainline/patches.git ../patches
    fi
    for p in ../patches/*.patch; do
        patch -p1 < "$p"
    done
    touch .patches_applied
fi

# 3. 配置内核
echo "=== 生成内核配置 ==="
make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE defconfig

# 基础配置：对齐hi3798mv100，适配GK6323
cat >> .config << EOF
# 基础系统支持
CONFIG_MODULES=y
CONFIG_MODULE_UNLOAD=y
CONFIG_PRINTK_TIME=y
CONFIG_CGROUPS=y
CONFIG_CGROUP_FREEZER=y
CONFIG_CGROUP_PIDS=y
CONFIG_CGROUP_DEVICE=y
CONFIG_CPUSETS=y
CONFIG_CGROUP_CPUACCT=y
CONFIG_NAMESPACES=y
CONFIG_NET_NS=y
CONFIG_PID_NS=y
CONFIG_IPC_NS=y
CONFIG_UTS_NS=y
CONFIG_USER_NS=y
CONFIG_BLK_DEV_INITRD=y
CONFIG_INITRAMFS_SOURCE=""
CONFIG_RD_GZIP=y
CONFIG_RD_BZIP2=y
CONFIG_RD_LZMA=y
CONFIG_RD_XZ=y
CONFIG_RD_LZO=y
CONFIG_RD_LZ4=y
CONFIG_CC_OPTIMIZE_FOR_SIZE=y
CONFIG_SYSVIPC=y
CONFIG_POSIX_MQUEUE=y
CONFIG_AUDIT=y
CONFIG_NO_HZ=y
CONFIG_HIGH_RES_TIMERS=y
CONFIG_PREEMPT=y
CONFIG_LOG_BUF_SHIFT=17
CONFIG_CGROUP_SCHED=y
CONFIG_FAIR_GROUP_SCHED=y
CONFIG_CFS_BANDWIDTH=y
CONFIG_RT_GROUP_SCHED=y
CONFIG_HZ_100=y
CONFIG_HZ=100

# eMMC/存储驱动
CONFIG_MMC=y
CONFIG_MMC_BLOCK=y
CONFIG_MMC_DW=y
CONFIG_MMC_DW_PLTFM=y
CONFIG_MMC_DW_HI3798CV200=y
CONFIG_EXT4_FS=y
CONFIG_EXT4_FS_POSIX_ACL=y
CONFIG_EXT4_FS_SECURITY=y
CONFIG_JBD2=y
CONFIG_FS_MBCACHE=y
CONFIG_F2FS_FS=y
CONFIG_VFAT_FS=y
CONFIG_FAT_DEFAULT_CODEPAGE=437
CONFIG_FAT_DEFAULT_IOCHARSET="utf8"
CONFIG_TMPFS=y
CONFIG_TMPFS_POSIX_ACL=y
CONFIG_TMPFS_XATTR=y

# 串口控制台
CONFIG_SERIAL_AMBA_PL011=y
CONFIG_SERIAL_AMBA_PL011_CONSOLE=y
CONFIG_SERIAL_OF_PLATFORM=y

# 网口驱动
CONFIG_NET=y
CONFIG_PACKET=y
CONFIG_UNIX=y
CONFIG_INET=y
CONFIG_IP_MULTICAST=y
CONFIG_IP_ADVANCED_ROUTER=y
CONFIG_IP_MULTIPLE_TABLES=y
CONFIG_IP_PNP=y
CONFIG_IP_PNP_DHCP=y
CONFIG_STMMAC_ETH=y
CONFIG_STMMAC_PLATFORM=y
CONFIG_HIX5HD2_GMAC=y
CONFIG_MDIO_BUS=y
CONFIG_FIXED_PHY=y

# USB控制器
CONFIG_USB=y
CONFIG_USB_ARCH_HAS_HCD=y
CONFIG_USB_EHCI_HCD=y
CONFIG_USB_EHCI_HCD_PLATFORM=y
CONFIG_USB_OHCI_HCD=y
CONFIG_USB_OHCI_HCD_PLATFORM=y
CONFIG_USB_XHCI_HCD=y
CONFIG_USB_XHCI_PLATFORM=y
CONFIG_USB_STORAGE=y
CONFIG_USB_SERIAL=y
CONFIG_USB_SERIAL_GENERIC=y

# ---------------- USB 声卡支持 ----------------
CONFIG_SOUND=y
CONFIG_SND=y
CONFIG_SND_HRTIMER=y
CONFIG_SND_SEQUENCER=y
CONFIG_SND_SEQUENCER_HRTIMER=y
CONFIG_SND_USB_AUDIO=y
CONFIG_SND_USB_AUDIO_USE_MEDIA_CONTROLLER=y
CONFIG_USB_AUDIO_CLASS_1=y
CONFIG_SND_USB_LINE6=m
CONFIG_SND_USB_CAIAQ=m
CONFIG_SND_USB_6FIRE=m
CONFIG_SND_USB_HIFACE=m
CONFIG_SND_USB_POD=m
CONFIG_SND_USB_PODHD=m
CONFIG_SND_USB_TONEPORT=m
CONFIG_SND_USB_VARIAX=m
# 板载音频支持(可选)
CONFIG_SND_SOC=y
CONFIG_SND_SOC_HISTB_AIAO=y
# ALSA工具支持
CONFIG_SND_PROC_FS=y
CONFIG_SND_CTL_FSMAP=y
CONFIG_SND_PCM_TIMER=y
# ------------------------------------------------

# 文件系统支持
CONFIG_NLS=y
CONFIG_NLS_DEFAULT="utf8"
CONFIG_NLS_CODEPAGE_437=y
CONFIG_NLS_ASCII=y
CONFIG_NLS_ISO8859_1=y
CONFIG_NLS_UTF8=y
CONFIG_CRYPTO_CRC32=y
CONFIG_CRYPTO_MD5=y
CONFIG_CRYPTO_SHA256=y

# 设备树内置支持
CONFIG_ARM64_APPENDED_DTB=y
CONFIG_ARM64_ERRATUM_843419=y
CONFIG_ARM64_ERRATUM_845719=y
CONFIG_OF=y
CONFIG_USE_OF=y
EOF

make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE olddefconfig

# 4. 编译内核
echo "=== 编译内核 ==="
make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE -j$(nproc) Image

# 5. 编译设备树
echo "=== 编译设备树: $DTB_NAME ==="
make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE -j$(nproc) hisilicon/$DTB_NAME

# 6. 拼接内核+DTB
echo "=== 拼接内核与设备树(内置DTB) ==="
cat arch/arm64/boot/Image arch/arm64/boot/dts/hisilicon/$DTB_NAME > Image-with-dtb

# 7. 制作uImage
echo "=== 制作uImage ==="
mkimage -A arm64 -O linux -T kernel -C none -a $LOAD_ADDR -e $ENTRY_POINT \
    -n "GK6323V100C Linux $KERNEL_VERSION ARM64" \
    -d Image-with-dtb boot.img

# 8. 编译模块
echo "=== 编译内核模块 ==="
make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE -j$(nproc) modules

# 9. 安装模块
echo "=== 安装模块 ==="
rm -rf ../modules
make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE INSTALL_MOD_PATH=../modules modules_install

# 10. 整理输出
cd ..
mkdir -p $OUTPUT_DIR
cp linux-$KERNEL_VERSION/boot.img $OUTPUT_DIR/boot.img
mv modules $OUTPUT_DIR/modules

echo ""
echo "=== 编译完成！输出产物: ==="
echo "1. 内核镜像: $OUTPUT_DIR/boot.img (替换原boot分区即可)"
echo "2. 模块目录: $OUTPUT_DIR/modules/lib/modules/ (解压覆盖到/lib/modules/)"
echo ""
echo "刷入方法:"
echo "1. 备份原有boot.img和模块目录"
echo "2. dd if=boot.img of=/dev/mmcblk0p15 bs=1M conv=fsync (boot分区号以实际分区表为准)"
echo "3. 解压modules到根目录: tar xf modules.tar.gz -C /"
echo "4. reboot 重启后插上USB声卡即可在/proc/asound/cards中看到"
