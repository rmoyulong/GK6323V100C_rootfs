#!/bin/sh
# flash-partition.sh
# 从 U 盘 / TF 卡启动的临时 Linux 里，把一个镜像写入板载 eMMC 的分区。
# 支持 rootfs.img.gz（自动 gunzip）与 boot.img / dtbo.img（原样写入）。
#
# 用法:
#   sh flash-partition.sh <镜像文件>              # 只做检查，不写入
#   sh flash-partition.sh <镜像文件> -y           # 确认后写入（默认目标 p18）
#   sh flash-partition.sh <镜像文件> -y /dev/mmcblk0p15   # 手动指定目标分区
#
# 前提: 已从 U 盘 / TF 卡启动，目标分区此刻没有被挂载为根。
set -eu

IMG=""
DEV=""
APPLY=0

for a in "$@"; do
    case "$a" in
        -y|--yes) APPLY=1 ;;
        /dev/*)   DEV="$a" ;;
        -*)       echo "未知选项: $a" >&2; exit 2 ;;
        *)        IMG="$a" ;;
    esac
done

die()  { echo "错误: $*" >&2; exit 1; }
info() { echo "==> $*"; }

[ -n "$IMG" ] || die "用法: sh flash-partition.sh <镜像文件> [-y] [/dev/mmcblkXpY]"
[ -f "$IMG" ] || die "找不到镜像文件: $IMG"

# ---------- 0. 镜像类型 ----------
IS_GZ=0
case "$IMG" in
    *.gz) IS_GZ=1 ;;
esac

# ---------- 1. 当前根设备，禁止自刷 ----------
root_src=$(awk '$2=="/"{print $1; exit}' /proc/mounts 2>/dev/null || echo "")
echo "当前根设备: ${root_src:-未知}"
case "$root_src" in
    *p18|*p15|*p10) die "当前根就在 eMMC 分区上，不能在线自刷；请从 U 盘/TF 卡启动后再运行本脚本" ;;
esac

# ---------- 2. 现场可见的候选分区，供人工核对 ----------
info "现场可见的 eMMC 分区:"
for d in /dev/mmcblk*p18 /dev/mmcblk*p15 /dev/mmcblk*p10; do
    [ -b "$d" ] || continue
    n=$(cat "/sys/class/block/$(basename "$d")/size" 2>/dev/null || echo 0)
    echo "    $d    $((n / 2 / 1024)) MiB"
done

# ---------- 3. 确定目标分区 ----------
if [ -z "$DEV" ]; then
    for d in /dev/mmcblk0p18 /dev/mmcblk1p18 /dev/mmcblk2p18; do
        [ -b "$d" ] && DEV="$d" && break
    done
fi
[ -n "$DEV" ] || die "没找到默认 p18，请手动指定，例如 /dev/mmcblk0p18"
[ -b "$DEV" ] || die "$DEV 不是块设备"
echo "目标分区:   $DEV"

# ---------- 4. 目标必须未被挂载 ----------
if grep -qs "^${DEV}[[:space:]]" /proc/mounts; then
    die "$DEV 正在被挂载，请先 umount 后再刷"
fi

# ---------- 5. 区域容量 vs 解压后镜像大小 ----------
n=$(cat "/sys/class/block/$(basename "$DEV")/size" 2>/dev/null || echo 0)
dev_mib=$((n / 2 / 1024))
echo "区域容量:   ${dev_mib} MiB"

if [ "$IS_GZ" -eq 1 ]; then
    raw_kib=$(gzip -l "$IMG" 2>/dev/null | awk 'NR==2{print $2}')
    if [ -n "${raw_kib:-}" ] && [ "${raw_kib:-0}" -gt 0 ] 2>/dev/null; then
        img_mib=$((raw_kib / 1024))
        echo "镜像(解压): ${img_mib} MiB"
        [ "$img_mib" -le "$dev_mib" ] || die "解压后镜像比分区大，拒绝写入"
    else
        echo "镜像(解压): 无法预读大小，靠 dd 写满自保护"
    fi
else
    img_bytes=$(wc -c < "$IMG")
    img_mib=$((img_bytes / 1024 / 1024))
    echo "镜像大小:   ${img_mib} MiB"
    [ "$img_mib" -le "$dev_mib" ] || die "镜像比分区大，拒绝写入"
fi

# ---------- 6. 完整性校验 ----------
if [ "$IS_GZ" -eq 1 ]; then
    info "校验压缩包完整性 ..."
    gunzip -t "$IMG" || die "压缩包损坏: $IMG"
fi

if [ -f "$IMG.sha256" ]; then
    info "校验 sha256 ..."
    ( cd "$(dirname "$IMG")" && sha256sum -c "$(basename "$IMG").sha256" ) || die "sha256 不匹配"
else
    echo "提示: 同目录没有 $IMG.sha256，跳过哈希校验"
fi

# ---------- 7. 落盘 ----------
if [ "$APPLY" -ne 1 ]; then
    echo
    info "检查通过，未写入。确认目标分区无误后加 -y 真正写入:"
    echo "    sh $0 $(basename "$IMG") -y $DEV"
    exit 0
fi

info "开始写入 $DEV （中途请勿断电）..."
if [ "$IS_GZ" -eq 1 ]; then
    gunzip -c "$IMG" | dd of="$DEV" bs=4M conv=fsync
else
    dd if="$IMG" of="$DEV" bs=4M conv=fsync
fi
sync

if command -v e2fsck >/dev/null 2>&1; then
    info "只读检查写入后的文件系统 ..."
    e2fsck -f -n "$DEV" || echo "    (e2fsck 报了非 0，首次开机仍会自动 fsck)"
fi

cat <<EOF

完成。接下来:
  1. 关机 / 断电
  2. 拔掉 U 盘 / TF 卡
  3. 上电重启，进入新系统
  4. 首次开机 resize-once 会把根分区扩到整区
  5. 用与本内核同批的 modules.tar.gz 覆盖 /lib/modules
EOF
