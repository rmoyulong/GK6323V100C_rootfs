# GK6323V100C 内核编译说明
适用于刷了 histb Debian 固件的国科 GK6323V100C 盒子，补充 USB 声卡支持，输出产物与 `hi3798mv100` 仓库格式完全一致：**内置 DTB 的 uImage 内核 + 模块目录**。

---

## 快速编译（在x86_64 Linux机器上执行）
### 1. 安装交叉编译工具链
```bash
# Debian/Ubuntu
sudo apt install gcc-aarch64-linux-gnu build-essential libncurses-dev bison flex libssl-dev libelf-dev bc u-boot-tools
```

### 2. 一键编译
```bash
chmod +x build.sh
./build.sh
```
编译完成后，产物在 `output/` 目录下：
- `boot.img`：带内置DTB的uImage内核，可直接替换原分区
- `modules/`：完整内核模块目录，包含snd-usb-audio驱动

---

## 兼容当前Debian系统的优化方案（推荐）
如果想最大程度兼容作者现有Debian系统的驱动（WiFi/蓝牙/硬件加速等），**不用重新从零配置**，直接从运行中的内核提取配置再补USB音频即可：

1. 在你已经刷好Debian的盒子上执行：
```bash
# 从运行内核提取配置
zcat /proc/config.gz > /tmp/running.config
# 拷贝到编译机
scp /tmp/running.config user@编译机IP:/path/to/gk6323-kernel/
```

2. 替换build.sh中的配置生成步骤，直接用现有配置：
```bash
# 注释掉原来的defconfig和cat >> .config部分，换成：
cp /path/to/running.config .config
# 打开USB音频配置
scripts/config --enable CONFIG_SOUND
scripts/config --enable CONFIG_SND
scripts/config --enable CONFIG_SND_USB_AUDIO
scripts/config --module CONFIG_SND_USB_AUDIO
scripts/config --enable CONFIG_SND_HRTIMER
scripts/config --enable CONFIG_SND_SEQUENCER
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
```
这样编译出来的内核和作者原内核**100%驱动兼容**，只多了USB声卡支持，不会出现网口/eMMC/WiFi失效的问题。

---

## 刷入步骤（在盒子上执行）
### 1. 先备份现有系统
```bash
# 备份原boot镜像
dd if=/dev/mmcblk0p17 of=/root/boot.img.bak bs=1M conv=fsync
# 备份原模块目录
tar czf /root/modules.bak.tar.gz /lib/modules/
```

### 2. 替换内核
```bash
# 把新的boot.img传到盒子/root目录
dd if=/root/boot.img of=/dev/mmcblk0p15 bs=1M conv=fsync
sync
```
> 注意：分区号`mmcblk0p15`对应dtbo/boot分区，请先用`ls -l /dev/disk/by-partlabel/`确认你的boot分区号，作者Debian分区表通常boot在p15。

### 3. 安装模块
```bash
# 把modules目录传到盒子
cp -r modules/lib/modules/6.18.46* /lib/modules/
depmod -a
sync
```

### 4. 重启
```bash
reboot
```

---

## 验证USB声卡
重启后插上USB声卡，执行：
```bash
lsusb
cat /proc/asound/cards
aplay -l
```
能看到USB声卡设备即成功，用`alsamixer`调整音量即可使用。

---

## 配置项说明
默认已开启的USB音频相关配置：
- `CONFIG_SND_USB_AUDIO`：USB音频核心驱动（必须）
- `CONFIG_SND_USB_AUDIO_USE_MEDIA_CONTROLLER`：媒体控制器支持
- `CONFIG_USB_AUDIO_CLASS_1`：USB Audio Class 1.0兼容（老声卡）
- `CONFIG_SND_SEQUENCER`：ALSA音序器支持（MIDI等）
- `CONFIG_SND_HRTIMER`：高精度定时器（低延迟音频）

常见USB声卡（USB DAC、USB麦克风、USB音箱）全部免驱支持，包括常见的CM108、CM6206、ES9018/ES9038 DAC、PS3/PS4 USB声卡等。

---

## 注意事项
1. 本内核基于主线6.18.46 + histb海思补丁，完全兼容Hi3798MV310/MV320/GK6323V100C
2. 加载/入口地址与原作者内核完全一致：`0x2000000`，无压缩，DTB内置在Image末尾
3. 如果开机卡住，用TTL看串口日志，大概率是DTB不匹配，换成对应你主板的DTB重新拼接即可
4. 所有原厂底层分区（atf/bootargs/fastboot）都不改动，仅替换boot和modules，可随时回滚：
   ```bash
   dd if=/root/boot.img.bak of=/dev/mmcblk0p17 bs=1M conv=fsync
   tar xzf /root/modules.bak.tar.gz -C /
   reboot
   ```

| 分区 | 设备节点 | 起始/大小 |
| --- | --- | --- |
| fastboot | p1 | 0 / 1M |
| bootargs | p2 | 1M / 512K |
| bootargsbak | p3 | 1.5M / 512K |
| recovery | p4 | 2M / 20M |
| deviceinfo | p5 | 22M / 2M |
| securestore | p6 | 24M / 8M |
| atf | p7 | 32M / 2M |
| baseparam | p8 | 34M / 8M |
| pqparam | p9 | 42M / 8M |
| dtbo | p10 | 50M / 2M |
| logo | p11 | 52M / 10M |
| logobak | p12 | 62M / 10M |
| fastplay | p13 | 72M / 20M |
| recoverybak | p14 | 92M / 20M |
| ‌boot‌ | ‌p15‌ | ‌112M / 60M‌ |
| misc | p16 | 172M / 20M |
| trustedcore | p17 | 192M / 20M |
| rootfs | p18 | 212M / 7.07G，已挂 / |

boot 就是 /dev/mmcblk0p15（起始 229376 扇区即 112M、长度 122880 扇区正好 60M）