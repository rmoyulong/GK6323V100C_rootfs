#!/bin/bash
set -euo pipefail

# ============================================================
# GK6323V100C 目标机刷写脚本：先装模块，再写 boot 分区（可选写 dtbo）
#
# 用法：
#   sudo bash flash-boot.sh -i boot.img -m modules.tar.gz \
#        [-d hi3798mv200h-skyworth-stb.dtb] [-p /dev/mmcblk0p15] [-D /dev/mmcblk0p10] [-n]
#
#   -i  uImage 内核镜像（Release 里的 boot.img）
#   -m  内核模块包（Release 里的 modules.tar.gz）
#   -d  设备树（可选；只有引导器不认内核内嵌 dtb 时才需要写 dtbo）
#   -p  boot 分区节点，默认 /dev/mmcblk0p15（起始 112M、长 60M）
#   -D  dtbo 分区节点，默认 /dev/mmcblk0p10（起始 50M、长 2M）
#   -n  只打印将要执行的动作，不落盘（先看一遍再加 sudo 执行）
#
# 顺序由脚本保证：先展开模块、后写内核，不要手工颠倒。
# 脚本不碰 fastboot / bootargs / atf / trustedcore 这些底层分区。
# ============================================================

BOOT_PART=/dev/mmcblk0p15
DTBO_PART=/dev/mmcblk0p10
BOOT_PART_SECTORS=122880   # 60M
DTBO_PART_SECTORS=4096     # 2M
IMG=""
MODULES=""
DTB=""
PART_GIVEN=0
DRY=0

usage() { sed -n '3,18p' "$0"; exit 1; }

while getopts "i:m:d:p:D:nh" opt; do
  case "$opt" in
    i) IMG="$OPTARG" ;;
    m) MODULES="$OPTARG" ;;
    d) DTB="$OPTARG" ;;
    p) BOOT_PART="$OPTARG"; PART_GIVEN=1 ;;
    D) DTBO_PART="$OPTARG" ;;
    n) DRY=1 ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

[ -n "$IMG" ] && [ -n "$MODULES" ] || usage
[ "$(id -u)" -eq 0 ] || { echo "需要 root：请用 sudo 运行"; exit 1; }
for f in "$IMG" "$MODULES"; do
  [ -f "$f" ] || { echo "文件不存在：$f"; exit 1; }
done
if [ -n "$DTB" ]; then
  [ -f "$DTB" ] || { echo "文件不存在：$DTB"; exit 1; }
fi

# 分区扇区数（每扇区 512 字节）
part_sectors() {
  local dev="$1" name
  name="$(basename "$dev")"
  if [ -r "/sys/class/block/$name/size" ]; then
    cat "/sys/class/block/$name/size"
  elif command -v blockdev >/dev/null 2>&1; then
    blockdev --getsz "$dev"
  else
    echo 0
  fi
}

BOOT_SECT="$(part_sectors "$BOOT_PART")"
[ "$BOOT_SECT" -gt 0 ] || {
  echo "读不到 $BOOT_PART 的大小，请先确认分区节点：cat /proc/partitions"
  exit 1
}
if [ "$BOOT_SECT" -ne "$BOOT_PART_SECTORS" ]; then
  if [ "$PART_GIVEN" -eq 1 ]; then
    echo "注意：$BOOT_PART 是 $BOOT_SECT 扇区，与默认 boot 分区的 $BOOT_PART_SECTORS 扇区不同，按 -p 指定的节点继续"
  else
    echo "拒绝写入：$BOOT_PART 是 $BOOT_SECT 扇区，而本机型 boot 分区应为 $BOOT_PART_SECTORS 扇区（60M，起始 112M）"
    echo "        分区布局不同时请用 -p 明确指定节点，确认无误再执行"
    exit 1
  fi
fi
BOOT_BYTES=$((BOOT_SECT * 512))

IMG_BYTES=$(stat -c%s "$IMG")
if [ "$IMG_BYTES" -gt "$BOOT_BYTES" ]; then
  echo "拒绝写入：内核镜像 $IMG_BYTES 字节 > boot 分区 $BOOT_BYTES 字节"
  exit 1
fi

if [ -n "$DTB" ]; then
  DTBO_SECT="$(part_sectors "$DTBO_PART")"
  if [ "$DTBO_SECT" -gt 0 ]; then
    DTBO_BYTES=$((DTBO_SECT * 512))
    DTB_BYTES=$(stat -c%s "$DTB")
    if [ "$DTB_BYTES" -gt "$DTBO_BYTES" ]; then
      echo "拒绝写入：设备树 $DTB_BYTES 字节 > dtbo 分区 $DTBO_BYTES 字节"
      exit 1
    fi
  else
    echo "读不到 $DTBO_PART 的大小，跳过 dtbo 写入"
    DTB=""
  fi
fi

run() {
  if [ "$DRY" -eq 1 ]; then
    echo "[dry-run] $*"
  else
    echo "+ $*"
    "$@"
  fi
}

BK="/root/boot-backup-$(date +%Y%m%d-%H%M%S).img"
echo "=========================================="
echo "内核镜像：$IMG（$IMG_BYTES 字节）"
echo "模块包　：$MODULES"
echo "boot 分区：$BOOT_PART（$BOOT_BYTES 字节）"
[ -n "$DTB" ] && echo "设备树　：$DTB -> $DTBO_PART"
echo "=========================================="

echo "== 1/4 备份当前 boot 分区 -> $BK"
run dd if="$BOOT_PART" of="$BK" bs=1M conv=fsync
[ "$DRY" -eq 1 ] || { sync; ls -l "$BK"; }

echo "== 2/4 安装内核模块（解出 /lib/modules/<release>）"
if [ "$DRY" -eq 1 ]; then
  echo "[dry-run] tar -xzf $MODULES -C /"
else
  tar -xzf "$MODULES" -C /
  sync
  if command -v depmod >/dev/null 2>&1; then
    for d in /lib/modules/*; do
      [ -f "$d/modules.dep" ] || [ -d "$d/kernel" ] || continue
      case "$(basename "$d")" in
        */build) continue ;;
      esac
      if [ -z "${NEWREL:-}" ] && [ -d "$d/kernel" ] && [ ! -e "$d/build" ]; then NEWREL="$(basename "$d")"; fi
    done
    [ -n "${NEWREL:-}" ] && { depmod -a "$NEWREL" || echo "depmod 失败，可稍后手动 depmod -a $NEWREL"; }
  fi
fi

echo "== 3/4 写入内核镜像 -> $BOOT_PART"
run dd if="$IMG" of="$BOOT_PART" bs=1M conv=fsync
[ "$DRY" -eq 1 ] || sync

if [ -n "$DTB" ]; then
  echo "== 4/4 写入设备树 -> $DTBO_PART"
  run dd if="$DTB" of="$DTBO_PART" bs=1K conv=fsync
  [ "$DRY" -eq 1 ] || sync
else
  echo "== 4/4 未指定设备树（-d），跳过 dtbo"
fi

echo
echo "完成。现在可以 reboot。"
echo "首次启动建议接 TTL 串口看输出；起来后跑一次 scripts/verify-device.sh。"
echo "回滚：dd if=$BK of=$BOOT_PART bs=1M conv=fsync && sync && reboot"
