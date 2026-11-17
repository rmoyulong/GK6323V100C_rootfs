# 故障排查：GK6323V100C

按「现象 → 原因 → 处理」组织。分区号一律以这台实机为准：`boot = /dev/mmcblk0p15`、
`dtbo = /dev/mmcblk0p10`、`rootfs = /dev/mmcblk0p18`。

---

## 一、构建阶段

### 1. 版本校验失败

- 现象：`版本不匹配：期望 7.4-rc2，实际 xxx`。
- 原因：补丁库的 `baseline` 已经往前走，而仓库里 pin 的 `PATCHES_BASE_SHA` 还是旧的。
- 处理：把 `PATCHES_BASE_SHA` 与 `PATCHES_KERNEL_VERSION` 跟着补丁库 `baseline` 一起改，
  两者必须同时改、且逐字一致。

### 2. 补丁应用中止

- 现象：某个 `.patch` 报 `[FAIL]`，随后整体失败并回滚。
- 原因：补丁与内核树上下文不匹配，常发生在上游内核版本变了之后。
- 处理：确认 `PATCHES_BASE_SHA` 就是补丁库 `baseline` 里那个 commit；确认无误仍失败时，
  属于补丁库需要自行 rebase，不要在 CI 里开 `SKIP_ON_CONFLICT` 硬跳过。

### 3. 找不到板级设备树

- 现象：提示补丁库里没有 `hi3798mv200h-skyworth-stb` 相关 dts。
- 原因：所用补丁库这一版还没有 arm64 的 mv200h 板级支持。
- 处理：把 `PATCHES_REPO` 换成包含该板级的补丁库（仓库内 `arch/arm64/boot/dts/hisilicon/`
  下应能看到 `hi3798mv200.dtsi` 与该单板 dts），并把 `PATCHES_BASE_SHA` 随之对齐。

### 4. 必须项检查中止：`Error: CONFIG_xxx 未开启`

- 现象：日志走到「必须项：少一项这台机器就起不来或目标落空，直接中止」一节后停下，
  报某个符号未开启（本仓库第一版就倒在 `CONFIG_CMDLINE_PARTITION` 上）。
- 原因：**该符号的父菜单没开**。`CMDLINE_PARTITION` 的 prompt 条件是
  `if PARTITION_ADVANCED`，父项为 n 时它成了「无 prompt 符号」，写进 `.config` 的值会被
  `olddefconfig` 丢弃 —— fragment 里写了、`scripts/config --enable` 也执行了，最终仍是不开。
- 处理：把父符号写在子符号之前。本仓库已补齐这几对：

| 子符号 | 必须同写的父符号 |
| --- | --- |
| `CMDLINE_PARTITION` | `PARTITION_ADVANCED` |
| `HISI_FEMAC`、`HISI_FESTA_PHY` | `NET_VENDOR_HISILICON`、`PHYLIB` |
| `PHY_HISI_INNO_USB2` | `GENERIC_PHY`、`USB_PHY` |
| `NLS_CODEPAGE_*`、`NLS_UTF8` | `NLS` |
| `SERIAL_AMBA_PL011_CONSOLE` | `SERIAL_AMBA_PL011` |

- 自查：看日志里「=== 单板配置层逐行自检 ===」一节有没有
  `::warning::叠加层未生效：CONFIG_xxx=y`；有就是同一类问题，那一行漏了父符号。

### 5. 一列 `=m` 符号集体未生效：先查 `CONFIG_MODULES`

- 现象：日志「期望项」一节里，所有形如 `=m` 的项（如 `CONFIG_SND_HWDEP=m`、
  `CONFIG_SND_RAWMIDI=m`、`CONFIG_SND_USB_AUDIO=m`）集体报未生效，而 `=y` 的项全部 OK。
- 原因：**内核没开模块支持**。tristate 符号在 `CONFIG_MODULES=n` 时会被 kconfig 一律
  压成 n，写多少 `=m` 都不会生效；作者那版 BSP 内核正是 `CONFIG_MODULES=n` 的全内置内核。
- 处理：`CONFIG_MODULES=y` 已列入「必须项」，漏开会在构建阶段直接中止，不必等到刷机后才发现。
- 附带：`SND_USB_AUDIO` 会自动 `select SND_HWDEP`、`SND_RAWMIDI`，它自己生效后这两项随之而来。

### 6. 旧符号名造成的假告警：`CONFIG_USE_OF`

- 现象：日志里 `Warning: CONFIG_USE_OF 未生效`，但设备树相关驱动（时钟、pinctrl）都正常。
- 原因：`CONFIG_USE_OF` 自 5.x 起已从 Kconfig 移除，统一为 `CONFIG_OF`；arm64 由架构强制
  `select OF`，恒为 y。写旧名会被丢弃，逐行自检因此报「叠加层未生效」（假阳性）。
- 处理：叠加层与检查清单一律写 `CONFIG_OF=y`，本仓库已改。
- 通用做法：改符号名前先在内核源码里 `grep -rn "config <符号名>"` 确认它还存在。

### 7. 只有 `=m` 的 USB 音频项报「叠加层未生效」

- 现象：末尾「单板配置层逐行自检」里只有 `CONFIG_SND_USB_AUDIO=m`（有时还带
  `CONFIG_SND_HWDEP=m`、`CONFIG_SND_RAWMIDI=m`）报未生效，而最终 `.config` 里它们其实是 `=y`。
- 原因：逐行自检按 `=m` 逐字节比对，而下面两种情况都属正常：
  - `scripts/config --enable SND_USB_AUDIO` 对 tristate 符号是设成 `y`，会把叠加层里的
    `=m` 顶掉。要保留模块形态必须改用 `--module`。
  - `SND_HWDEP`、`SND_RAWMIDI` 是无 prompt 符号，取值只由 `select` 决定，`SND_USB_AUDIO`
    是什么它们就是什么。
- 处理：本仓库已把 CI 改成 `scripts/config --module SND_USB_AUDIO`，并让逐行自检对 `=m`
  行按 `[ym]` 判定；叠加层里也不再写那两个 select 符号。
  若希望 USB 音频编进内核（刷完不必装模块），把 CI 里那一行换回 `--enable` 即可，
  代价是 `modules.tar.gz` 里不再有 `snd-usb-audio.ko`。

## 二、刷机阶段

### 1. 拒绝写入 boot 分区

- 现象：`拒绝写入：/dev/mmcblk0p15 是 xxxxx 扇区，而本机型 boot 分区应为 122880 扇区`。
- 原因：分区布局与预期不符，说明这台机器不是本机型的那套布局。
- 处理：先 `cat /proc/partitions` 核对，找出 60M、起始 112M 的那个节点，再用 `-p` 指定。

### 2. 刷完起不来

- 现象：指示灯异常闪烁，TTL 无输出。
- 原因：内核与设备树不配套，或内核镜像不完整。
- 处理：用 `scripts/flash-boot.sh` 自动备份的那份镜像回滚：
  `dd if=/root/boot-backup-*.img of=/dev/mmcblk0p15 bs=1M conv=fsync && sync`。
  下次刷写前先接 TTL 再看一遍串口输出。

### 3. TTL 里看到内核起来了，但根文件系统挂不上

- 现象：`Kernel panic - not syncing: VFS: Unable to mount root fs`。
- 原因：命令行分区表没生效，内核看不到 `mmcblk0p18`。
- 处理：确认 `CONFIG_CMDLINE_PARTITION=y` 在 `config-<release>` 里；同时确认 bootargs
  分区（`/dev/mmcblk0p2`）没被改动，里面的 `blkdevparts=` 与 `root=` 是这台机器的原值。

## 三、起得来但功能不对

### 1. 插上 USB 声卡还是没声音

按顺序查：

```bash
uname -r                                   # 内核换了吗
ls /proc/modules | grep snd_usb            # 模块在不在
modinfo snd-usb-audio                      # 驱动认不认得
cat /proc/asound/cards                     # 声卡列出来了吗
lsusb -t                                   # Audio 接口的 Driver 一栏
```

- `/lib/modules/<release>` 不存在：模块没装。回到第四节第 2 步先解开 `modules.tar.gz`。
- 模块存在但没加载：`modprobe snd-usb-audio`，再看 `dmesg | tail`。
- `lsusb -t` 里 Audio 接口 Driver 为空：驱动没接管，回到上一节查内核配置。

### 2. 找不到 /proc/modules

- 现象：`lsmod` 报 `could not open /proc/modules`。
- 原因：这是纯内置内核的特征（作者那版 BSP 内核就是这样），说明 boot 分区没换成新内核。
- 处理：确认 `dd` 写的是 `boot = /dev/mmcblk0p15`，写完执行 `sync` 再重启。

### 3. 设备树不是 mv200h 这一支

- 现象：`/sys/firmware/devicetree/base/model` 里没有 `mv200h` / `skyworth` 字样。
- 原因：引导器用的是 dtbo 分区里的旧设备树，没采用内核内嵌的那份。
- 处理：把 Release 里的 `hi3798mv200h-skyworth-stb.dtb` 写进 `/dev/mmcblk0p10`：

```bash
sudo dd if=hi3798mv200h-skyworth-stb.dtb of=/dev/mmcblk0p10 bs=1K conv=fsync && sync && reboot
```

### 4. 网络不通

- 现象：`ip -br link` 里 `eth0` 不是 `UP`。
- 原因：femac 或 PHY 没起来。
- 处理：`dmesg | grep -i -E "femac|festa|eth0"` 看驱动是否 probe 成功；
  确认 `config-<release>` 里 `CONFIG_HISI_FEMAC=y`、`CONFIG_HISI_FESTA_PHY=y`。

> 刷写过程中不要断电。boot 分区只有 60M，写入的镜像必须是同一个 Release 里那一份；
> 换内核请连模块一起换，两者版本号必须一致。
