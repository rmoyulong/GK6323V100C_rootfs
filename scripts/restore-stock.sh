#!/bin/bash
# ============================================================
# 救砖：把原版 boot / dtbo 写回，让机器回到国科原版（或作者 Debian）状态。
#
# 用法（在能跑的系统里不方便，因为砖了进不去系统；一般配合 TTL / HiTool 使用）：
#   sudo bash restore-stock.sh -b /path/or/boot.img [-d /path/or/dtbo.img]
#
#   -b  原版 boot 镜像（作者 Debian 的 boot.img，或你自己的备份）
#   -d  原版 dtbo 镜像（可选；若之前动过 dtbo 才需要）
#   -B  boot 分区节点，默认 /dev/mmcblk0p15
#   -D  dtbo 分区节点，默认 /dev/mmcblk0p10
#   -n  只打印，不落盘
#
# 注意：机器已不断重启时，系统进不去，这个脚本跑不了；
#       那种情况请用 HiTool（网口）按分区表刷回 boot.img / dtbo.img，
#       或从 TTL 进 uboot 用 tftp/usb 加载后写入。
# ============================================================
set -euo pipefail

BOOT_PART=/dev/mmcblk0p15
DTBO_PART=/dev/mmcblk0p10
BOOT_IMG=""
DTBO_IMG=""
DRY=0

while getopts "b:d:B:D:nh" opt; do
  case "$opt" in
    b) BOOT_IMG="$OPTARG" ;;
    d) DTBO_IMG="$OPTARG" ;;
    B) BOOT_PART="$OPTARG" ;;
    D) DTBO_PART="$OPTARG" ;;
    n) DRY=1 ;;
    *) sed -n '2,14p' "$0"; exit 1 ;;
  esac
done

[ -n "$BOOT_IMG" ] || { echo "必须用 -b 给出原版 boot 镜像"; exit 1; }
[ -f "$BOOT_IMG" ] || { echo "找不到 $BOOT_IMG"; exit 1; }
[ -b "$BOOT_PART" ] || { echo "$BOOT_PART 不是块设备"; exit 1; }

run() { if [ "$DRY" -eq 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }

echo "== 写回 boot：$BOOT_IMG -> $BOOT_PART"
run dd if="$BOOT_IMG" of="$BOOT_PART" bs=1M conv=fsync
[ "$DRY" -eq 1 ] || sync

if [ -n "$DTBO_IMG" ]; then
  [ -f "$DTBO_IMG" ] || { echo "找不到 $DTBO_IMG"; exit 1; }
  echo "== 写回 dtbo：$DTBO_IMG -> $DTBO_PART"
  run dd if="$DTBO_IMG" of="$DTBO_PART" bs=1K conv=fsync
  [ "$DRY" -eq 1 ] || sync
else
  echo "== 未给 -d，跳过 dtbo"
fi

echo
echo "完成后 reboot。若 boot 与 dtbo 没有同时换回原版，仍会红灯；"
echo "本脚本只负责把国科原版内核/设备树放回去。"
