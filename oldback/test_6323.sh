#!/bin/bash
# dump-hwinfo.sh - GK6323V100C 真机硬件信息采集
mkdir -p /root/hwinfo
cd /root/hwinfo

echo "=== 1. 基础系统信息 ===" > report.txt
uname -a >> report.txt
cat /proc/cpuinfo >> report.txt
cat /proc/meminfo | head -5 >> report.txt
cat /proc/cmdline >> report.txt

echo -e "\n=== 2. 完整设备树导出 ===" >> report.txt
# 直接导出内核正在使用的DTB，后续基于它改
dtc -I fs /sys/firmware/devicetree/base -o real-devicetree.dts 2>&1
ls -l real-devicetree.dts >> report.txt

echo -e "\n=== 3. 中断控制器信息 ===" >> report.txt
cat /proc/interrupts | head -30 >> report.txt
ls -l /sys/firmware/devicetree/base/interrupt-controller* >> report.txt 2>&1
for f in /sys/firmware/devicetree/base/interrupt-controller*/compatible; do echo "$f: $(cat $f)"; done >> report.txt
for f in /sys/firmware/devicetree/base/interrupt-controller*/reg; do echo -n "$f: "; hexdump -e '"0x%08x "' $f; echo; done >> report.txt

echo -e "\n=== 4. 时钟控制器信息 ===" >> report.txt
ls -l /sys/firmware/devicetree/base/clock-controller* >> report.txt 2>&1
for f in /sys/firmware/devicetree/base/clock-controller*/compatible; do echo "$f: $(cat $f)"; done >> report.txt
for f in /sys/firmware/devicetree/base/clock-controller*/reg; do echo -n "$f: "; hexdump -e '"0x%08x "' $f; echo; done >> report.txt
cat /sys/kernel/debug/clk/clk_summary 2>/dev/null | head -80 >> report.txt || echo "clk_debugfs不可用" >> report.txt

echo -e "\n=== 5. 内存映射 ===" >> report.txt
cat /proc/iomem | head -50 >> report.txt

echo -e "\n=== 6. 所有外设compatible列表 ===" >> report.txt
find /sys/firmware/devicetree/base -name compatible -exec echo -n "{}: " \; -exec cat {} \; | grep -v "lkdtm\|cpus\|memory\|chosen\|psci" | sort >> report.txt

echo -e "\n=== 7. UART控制台信息 ===" >> report.txt
ls -l /sys/firmware/devicetree/base/serial* >> report.txt 2>&1
for f in /sys/firmware/devicetree/base/serial*/compatible; do echo "$f: $(cat $f)"; done >> report.txt

echo -e "\n=== 8. eMMC/SD信息 ===" >> report.txt
ls -l /sys/firmware/devicetree/base/mmc* >> report.txt 2>&1
for f in /sys/firmware/devicetree/base/mmc*/compatible; do echo "$f: $(cat $f)"; done >> report.txt
cat /proc/partitions | grep mmc >> report.txt

echo -e "\n=== 9. 网口信息 ===" >> report.txt
ls -l /sys/firmware/devicetree/base/ethernet* >> report.txt 2>&1
for f in /sys/firmware/devicetree/base/ethernet*/compatible; do echo "$f: $(cat $f)"; done >> report.txt
ip link show >> report.txt

echo -e "\n=== 10. USB控制器信息 ===" >> report.txt
ls -l /sys/firmware/devicetree/base/usb* >> report.txt 2>&1
lsusb -t >> report.txt 2>&1

echo -e "\n=== 采集完成，文件列表 ==="
ls -l /root/hwinfo/
