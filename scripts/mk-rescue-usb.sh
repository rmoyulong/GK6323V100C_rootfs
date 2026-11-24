#!/bin/sh
# mk-rescue-usb.sh
# 在一块 U 盘上做一个 GK6323V100C（ChaoGe Z71A）的救援系统盘。
#
# 在哪跑：一台已经起来的 Linux 上。最方便的就是让板子继续跑它现有的
#         系统，把 U 盘插到板子的 USB 口，直接在板子上做。
#
# 用法：
#   sudo sh mk-rescue-usb.sh /dev/sdX rescue-rootfs.tar [rootfs.img.gz]
#
#   参数 1  U 盘块设备节点（用 -l 可以先只看不写）
#   参数 2  Buildroot 编出来的 rootfs.tar
#   参数 3  可选；要刷进 eMMC p18 的 rootfs.img.gz，放进救援盘的 /flash
#
# 产物：整盘一个 ext4 文件系统（不建分区表），U-Boot/内核用 root=/dev/sda
#       或 root=UUID=<脚本最后打印的那个> 引导。
set -eu

LIST=0
DEV=""
TAR=""
GZ=""

for a in "$@"; do
    case "$a" in
        -l|--list)      LIST=1 ;;
        /dev/*)         DEV="$a" ;;
        *.img.gz)       GZ="$a" ;;
        *.tar|*.tar.gz|*.tgz) TAR="$a" ;;
    esac
done

die()  { echo "错误: $*" >&2; exit 1; }
info() { echo "==> $*"; }

list_disks() {
    echo "当前可移动磁盘（按容量核对，别选错）："
    for d in /sys/block/sd*; do
        [ -e "$d" ] || continue
        n=$(basename "$d")
        [ "$(cat "$d/removable" 2>/dev/null || echo 0)" = "1" ] || continue
        sz=$(( $(cat "$d/size" 2>/dev/null || echo 0) / 2 / 1024 ))
        echo "    /dev/$n    ${sz} MiB"
    done
}

if [ "$LIST" -eq 1 ]; then
    list_disks
    exit 0
fi

[ -n "$DEV" ] || { list_disks; die "用法: sudo sh $0 /dev/sdX rescue-rootfs.tar [rootfs.img.gz]"; }
[ -n "$TAR" ] || die "缺少 Buildroot 的 rootfs.tar（第 2 个参数）"
[ -b "$DEV" ] || die "$DEV 不是块设备"
[ -f "$TAR" ] || die "找不到 $TAR"
if [ -n "$GZ" ]; then [ -f "$GZ" ] || die "找不到 $GZ"; fi

# 护卫 1：绝不写板载 eMMC / SD
case "$DEV" in
    *mmcblk*) die "$DEV 是板载 eMMC/SD，拒绝写入。确认 U 盘节点后再来" ;;
esac
# 护卫 2：绝不写当前根设备
root_src=$(awk '$2=="/"{print $1; exit}' /proc/mounts 2>/dev/null || echo "")
if [ "$root_src" = "$DEV" ]; then
    die "$DEV 就是当前根设备，拒绝写入"
fi

echo "=================================================="
echo "U 盘节点 ：$DEV"
echo "救援系统 ：$TAR"
echo "待刷镜像 ：${GZ:-（未指定，救援盘不含 rootfs.img.gz）}"
echo "=================================================="
list_disks
echo
printf "确认把 %s 整盘重建？会清空上面的全部数据。输入 yes 继续: " "$DEV"
read -r ans </dev/tty || ans=""
[ "$ans" = "yes" ] || die "已取消"

info "卸载 $DEV 上已挂载的分区"
for p in "$DEV"*; do
    [ -b "$p" ] || continue
    umount "$p" 2>/dev/null || true
done
umount "$DEV" 2>/dev/null || true

info "清除旧签名并创建 ext4 文件系统"
wipefs -a "$DEV" 2>/dev/null || true
dd if=/dev/zero of="$DEV" bs=1M count=4 conv=fsync status=none 2>/dev/null || true
mkfs.ext4 -F -L gkrescue "$DEV"

info "展开救援系统"
MNT=$(mktemp -d)
mount "$DEV" "$MNT"
tar xpvf "$TAR" -C "$MNT"

if [ -n "$GZ" ]; then
    info "放入待刷镜像：/flash/$(basename "$GZ")"
    mkdir -p "$MNT/flash"
    cp "$GZ" "$MNT/flash/"
fi

sync
umount "$MNT"
rmdir "$MNT"

UUID=$(blkid -o value -s UUID "$DEV" 2>/dev/null || true)

cat <<EOF

完成。U-Boot 里引导时用下面两个参数之一：
    root=UUID=${UUID:-读不到UUID，就用 root=/dev/sda}
    root=/dev/sda

接着在 TTL 串口按手册执行引导命令，进救援系统后刷 eMMC 的 p18。
EOF
