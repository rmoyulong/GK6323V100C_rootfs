# 分区表（真机实测）

数据来源：原版 Debian 启动时 U-Boot 打印的 `blkdevparts=mmcblk0:` 与 sysfs 验证。
所有分区按 LBA=512B 计算，起始块与长度均为扇区数。

| 编号 | 名称 | 起始扇区 | 大小 | 用途 |
| --- | --- | --- | --- | --- |
| 1 | xloader | 0 | 1 MB | BootROM 加载的一级引导 |
| 2 | fastboot | — | 1 MB | fastboot 模式 |
| 3 | nvram | — | 2 MB | NVRAM 配置 |
| 4 | reserved0 | — | 4 MB | 厂商保留 |
| 5 | reserved1 | — | 4 MB | 厂商保留 |
| 6 | logo | — | 8 MB | 开机动画 |
| 7 | misc | — | 4 MB | 系统 misc |
| 8 | odmko | — | 8 MB | 厂商内核模块 |
| 9 | bootargs | 0x11000 | 256 KB | bootargs 环境变量（root=/mmcblk0p18、blkdevparts 等） |
| 10 | **dtbo (p10)** | **0x19000** | **2 MB** | **设备树 —— 本仓库 dtb 写入这里** |
| 11 | tee | — | 8 MB | OP-TEE 安全 OS |
| 12 | vbmeta | — | 2 MB | Android Verified Boot |
| 13 | reserved2 | — | 4 MB | 保留 |
| 14 | vendor | — | 16 MB | 厂商分区 |
| 15 | **boot (p15)** | **0x38000** | **60 MB** | **内核镜像 boot.img —— 本仓库 uImage 写入这里** |
| 16 | recovery | — | 32 MB | recovery 模式 |
| 17 | cache | — | 256 MB | cache |
| 18 | rootfs | 0xB0000 | 约 1.1 GB | Debian rootfs（ext4） |
| 19 | userdata | — | 剩余空间 | 用户数据 |

---

## 关键刷写地址（U-Boot）

```
mmc read 0 0x04000000 0x38000 0x7800   # 把 p15（boot，60MB）读到 0x04000000
mmc read 0 0x03FFC000 0x19000 0x20     # 把 p10（dtbo，只读前 16KB）读到 0x03FFC000
bootm 0x04000000                       # 启动；ATF 自动把 0x03FFC000 的 dtb 传给内核
```

## 设备树窗口硬约束

- U-Boot 只读 p10 的前 `0x20 = 32` 扇区 = **16 KiB**
- dtb 超过 16 KiB 就会被截断，内核解析失败 → 起不来
- 作者原 dtb：9156 字节；本仓库 dts 目标：≤ 10 KB

## 验证分区（进系统后）

```bash
for p in /sys/block/mmcblk0/mmcblk0p*; do
    echo "$(basename $p) start=$(cat $p/start) size=$(cat $p/size)"
done
```

对照输出里的 `start` 与上表，确认没有偏移再刷写。
