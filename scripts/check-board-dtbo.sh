#!/bin/bash
# ============================================================
# 读出 dtbo 分区（或给定镜像），打印硬件指纹，判断这台机器
# 是不是本仓库内核的目标机。
#
#   看到 goke,gk6323v100c / cortex-a55 / arm,gic-v3
#       -> 正是本仓库的目标机（国科 GK6323V100C），可以刷
#   看到 hisilicon,hi3798mv200 / cortex-a53 / arm,gic-400
#       -> 是海思 MV200H 那一类机型，**不要**刷本仓库内核
#
# 用法：
#   sudo bash check-board-dtbo.sh                 # 读 /dev/mmcblk0p10
#   sudo bash check-board-dtbo.sh /dev/mmcblk0p10 /tmp/dtbo.img
#   bash check-board-dtbo.sh ./dtbo.img           # 直接给一个镜像文件
# ============================================================
set -euo pipefail

SRC=${1:-/dev/mmcblk0p10}
OUT=${2:-/tmp/dtbo-dump.img}

if [ -b "$SRC" ]; then
  echo "== 从分区读取：$SRC -> $OUT"
  dd if="$SRC" of="$OUT" bs=1M conv=fsync 2>/dev/null || dd if="$SRC" of="$OUT" bs=1M
else
  OUT="$SRC"
  echo "== 使用镜像文件：$OUT"
fi

[ -f "$OUT" ] || { echo "读不到 $OUT"; exit 1; }
echo "镜像大小：$(stat -c%s "$OUT" 2>/dev/null || wc -c <"$OUT") 字节"
echo "== 硬件指纹 =="

python3 - "$OUT" <<'PY'
import sys
raw = open(sys.argv[1], 'rb').read()
# 只在第一个 FDT 内部找特征串
i = raw.find(b'\xd0\x0d\xfe\xed')
if i < 0:
    print("  未找到设备树魔数 d00dfeed —— 这个分区里没有 dtb。")
    sys.exit(0)
b = raw[i:i+65536]

def show(label, kws):
    hits = [k.decode() for k in kws if k in b]
    print("  %-14s %s" % (label, " / ".join(hits) if hits else "（未出现）"))

show("根 compatible", [b'goke,gk6323v100c', b'hisilicon,hi3798mv200', b'skyworth,hi3798mv200h'])
show("CPU",           [b'arm,cortex-a55', b'arm,cortex-a53'])
show("中断控制器",     [b'arm,gic-v3', b'arm,gic-400'])
show("PSCI",          [b'arm,psci-0.2', b'arm,psci-1.0'])
show("时钟控制器",     [b'gk6323v100c-cru', b'hi3798mv200-crg'])
show("存储",          [b'gk6323v100c-dw-mshc', b'hi3798mv200-dw-mshc'])

# model 字符串（可打印 ASCII 段里带 GK6323 或 Hi3798 的那条）
for tok in raw.replace(b'\x00', b'\x00').split(b'\x00'):
    if (b'GK6323' in tok or b'Hi3798' in tok) and 4 < len(tok) < 80 and all(32 <= c < 127 for c in tok):
        print("  %-14s %s" % ("model", tok.decode('latin1').lstrip(', ')))
        break

goke = b'goke,gk6323' in b or b'cortex-a55' in b or b'arm,gic-v3' in b
mv200 = b'hi3798mv200' in b or b'cortex-a53' in b or b'arm,gic-400' in b

print()
print("== 判定 ==")
if goke:
    print("  这台是国科 GK6323V100C（Cortex-A55 + GICv3）。")
    print("  正是本仓库内核的目标机，可以刷；先备份再刷，见 docs/build-and-flash.md。")
elif mv200:
    print("  看到海思 MV200H 一类特征（A53 + GIC-400），与本仓库目标机不同。")
    print("  **不要**刷本仓库内核，刷了会红灯循环重启。")
else:
    print("  没看到上述两族特征，无法判定，先不要刷。")
PY
