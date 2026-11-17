#!/bin/bash
set -uo pipefail

# ============================================================
# GK6323V100C 目标机自检：一条命令看新内核有没有真的生效、
# USB 声卡能不能用、以及刷错带来的可见后果。
#
# 用法：sudo bash verify-device.sh
# 七组检查，末尾给 PASS / FAIL / SKIP 汇总；有 FAIL 时退出码非 0。
#
# 说明：SKIP 表示「当前条件下测不了」，不算失败，例如没插 USB 声卡。
# ============================================================

PASS=0; FAIL=0; SKIP=0
ok()  { echo "    [PASS] $1"; PASS=$((PASS+1)); }
ng()  { echo "    [FAIL] $1"; FAIL=$((FAIL+1)); }
sk()  { echo "    [SKIP] $1"; SKIP=$((SKIP+1)); }
sec() { echo; echo "== $1 =="; }

echo "GK6323V100C 内核自检  时间：$(date '+%F %T')"

# ---- 1. 内核版本 ----
sec "1. 内核版本"
KREL="$(uname -r)"
echo "    运行内核：$KREL"
if [ "$KREL" = "6.18.46-gk6323-debian" ]; then
  ng "还是作者那版 BSP 内核，说明 boot 分区没换成功"
else
  ok "内核已替换（$KREL）"
fi
sed -n '1p' /proc/version | sed 's/^/    /'

# ---- 2. 模块支持 ----
sec "2. 模块支持"
if [ -r /proc/modules ]; then
  N="$(wc -l < /proc/modules)"
  ok "/proc/modules 可读，已加载模块 $N 个（内核带 CONFIG_MODULES）"
else
  ng "/proc/modules 不存在：这版内核仍是纯内置内核，insmod / modprobe 都用不了"
fi
if command -v modinfo >/dev/null 2>&1; then
  if modinfo snd-usb-audio >/dev/null 2>&1; then
    ok "snd-usb-audio 在内核或模块里可见"
  else
    ng "找不到 snd-usb-audio：USB 声卡驱动没编进去"
  fi
else
  sk "没有 modinfo 命令（kmod 未装），跳过驱动存在性检查"
fi

# ---- 3. 设备树 ----
sec "3. 设备树"
MODEL=""
for p in /sys/firmware/devicetree/base/model /proc/device-tree/model; do
  [ -r "$p" ] && { MODEL="$(tr -d '\0' < "$p")"; break; }
done
if [ -n "$MODEL" ]; then
  echo "    设备树 model：$MODEL"
  case "$MODEL" in
    *3798mv200h*|*skyworth*|*MV200H*) ok "板级设备树是 mv200h / 创维 这一支" ;;
    *) ng "设备树 model 不是 mv200h 这一支，dtb 可能没换" ;;
  esac
else
  sk "读不到设备树 model 节点"
fi

# ---- 4. 分区表与根文件系统 ----
sec "4. 分区表与根文件系统"
NPART="$(grep -c 'mmcblk0p' /proc/partitions || true)"
if [ "$NPART" -ge 18 ]; then
  ok "看到 $NPART 个 mmcblk0 分区（bootargs 里的 blkdevparts= 生效）"
else
  ng "只看到 $NPART 个 mmcblk0 分区，命令行分区表可能没生效"
fi
ROOTSRC="$(findmnt -no SOURCE / 2>/dev/null || true)"
ROOTFST="$(findmnt -no FSTYPE / 2>/dev/null || true)"
echo "    根分区：$ROOTSRC ($ROOTFST)"
if [ "$ROOTSRC" = "/dev/mmcblk0p18" ]; then
  ok "根分区在 /dev/mmcblk0p18"
else
  ng "根分区不是 /dev/mmcblk0p18，与本机型布局不符"
fi
if [ -d "/lib/modules/$KREL" ]; then
  ok "模块目录存在：/lib/modules/$KREL"
else
  ng "/lib/modules/$KREL 不存在：模块没装，或内核与模块不是同一版"
fi

# ---- 5. USB 主控 ----
sec "5. USB 主控"
if ls /sys/bus/usb/devices/ 2>/dev/null | grep -q 'usb'; then
  grep -H -m1 . /sys/bus/usb/devices/usb*/product 2>/dev/null | sed 's/^/    /' || true
  ok "USB 总线已枚举（$(ls -d /sys/bus/usb/devices/usb* 2>/dev/null | wc -l) 个根集线器）"
else
  ng "没有任何 USB 根集线器：EHCI/OHCI 驱动或 PHY 没起来"
fi

# ---- 6. USB 声卡 ----
sec "6. USB 声卡"
CARDS=""
[ -r /proc/asound/cards ] && CARDS="$(cat /proc/asound/cards)"
if [ -n "$CARDS" ]; then
  echo "$CARDS" | sed 's/^/    /'
  if echo "$CARDS" | grep -qi 'usb'; then
    ok "已识别到 USB 声卡"
  else
    echo "    以上没有 USB 声卡；若已插上 USB 声卡，说明驱动仍没接管"
  fi
else
  sk "/proc/asound/cards 不可读（没有 USB 声卡时也可能如此）"
fi
if command -v lsusb >/dev/null 2>&1; then
  if ! lsusb -t 2>/dev/null | grep -qi 'Audio'; then
    sk "USB 树里没有 Audio 接口（没插声卡时正常）"
  else
    lsusb -t 2>/dev/null | sed 's/^/    /'
    if lsusb -t 2>/dev/null | grep -i 'Audio' | grep -q 'snd-usb-audio'; then
      ok "Audio 接口已被 snd-usb-audio 接管"
    else
      ng "Audio 接口存在但 Driver 一栏为空：USB 音频驱动没接管"
    fi
  fi
else
  sk "没有 lsusb 命令，跳过 USB 树检查"
fi
if command -v aplay >/dev/null 2>&1; then
  aplay -l 2>/dev/null | sed 's/^/    /' || true
else
  sk "没有 aplay，跳过播放设备列表"
fi

# ---- 7. 网络 ----
sec "7. 网络"
if command -v ip >/dev/null 2>&1; then
  ip -br link 2>/dev/null | sed 's/^/    /' || true
  if ip -br link 2>/dev/null | grep -qE '^eth0(@[^ ]+)? +UP'; then
    ok "eth0 已 UP"
  else
    ng "eth0 没 UP：femac 或 PHY 没起来"
  fi
else
  sk "没有 ip 命令，跳过"
fi

echo
echo "=========================================="
echo "PASS=$PASS  FAIL=$FAIL  SKIP=$SKIP"
echo "=========================================="
[ "$FAIL" -eq 0 ] || exit 1
