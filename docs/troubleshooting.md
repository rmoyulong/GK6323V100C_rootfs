# 故障排查

按"构建阶段"和"刷写与启动阶段"两段列。每条都给出**现象—原因—处理**。

---

## 一、构建阶段（GitHub Actions）

### 1. 必须项检查中止：`CONFIG_CMDLINE_PARTITION 未开启`

- 现象：`Error: CONFIG_CMDLINE_PARTITION 未开启`，进程退 1。
- 原因：`CMDLINE_PARTITION` 的 prompt 条件是 `if PARTITION_ADVANCED`。
  父菜单为 `n` 时它是**无 prompt 符号**，写进 `.config` 的值会被
  `olddefconfig` 直接丢弃，哪怕 `scripts/config --enable` 执行过。
- 处理：把父菜单写在前面——
  `CONFIG_PARTITION_ADVANCED=y` 在前、`CONFIG_CMDLINE_PARTITION=y` 在后。
  本仓库已按此顺序写好。被 `if` 包住的符号都遵循这条：
  `HISI_FEMAC`/`HISI_FESTA_PHY` 在 `NET_VENDOR_HISILICON` 之下、
  `MDIO_HISI_FEMAC` 在 `OF_MDIO` 之下、
  `NLS_CODEPAGE_*` 在 `NLS` 之下、`PHY_HISI_INNO_USB2` 在
  `GENERIC_PHY`/`USB_PHY` 之下。
  另有一类**无 prompt 符号**不适用本条（父项开了也设不动），见第 8 条。

### 2. `叠加层未生效：CONFIG_SND_USB_AUDIO=m`

- 现象：逐行自检报 `SND_USB_AUDIO=m` 未生效。
- 原因：流水线里写成 `scripts/config --enable SND_USB_AUDIO` 时，对
  tristate 符号等于设成 `y`，把叠加层的 `=m` 顶掉，于是编成内置。
- 处理：这一行必须用 `scripts/config --module SND_USB_AUDIO`。
  本仓库已改；自检对 `=m` 行按 `[ym]` 判定，`=y` 不再算"未生效"。

### 3. 一堆 `=m` 符号集体未生效

- 现象：`SND_HWDEP`、`SND_RAWMIDI`、`SND_USB_AUDIO` 同时报未生效。
- 原因：通常是漏开 `CONFIG_MODULES=y`，内核不支持模块时 kconfig 会把所有
  tristate 符号丢成 `n`。
- 处理：确认配置里有 `CONFIG_MODULES=y`；本仓库已把它列入必须项。

### 4. `Warning: CONFIG_USE_OF 未生效`

- 现象：期望项告警 `CONFIG_USE_OF 未生效`。
- 原因：`CONFIG_USE_OF` 自 5.x 起已从 Kconfig 移除，统一叫 `CONFIG_OF`；
  arm64 上由架构强制 `select OF`，恒为 `y`。写旧名会被直接丢弃。
- 处理：写 `CONFIG_OF=y`。本仓库已改（配置、`scripts/config`、检查清单三处）。

### 5. 停在「查设备树」

- 现象：报找不到板级 dts。
- 说明：本仓库**不再要求**补丁库带板级设备树 —— 设备树是仓库自带的
  `dts/gk6323v100c-chaoge-z71a.dts`。若仍看到这条旧检查，说明跑的是旧版
  流水线，更新到最新版即可。

### 6. 设备树静态校验失败

- 现象：`校验未通过：N 个 ERROR`。
- 常见三类：漏分号、`&label` 引用了没定义的 label、节点名 `name@地址`
  与 `reg` 首地址不符。
- 处理：按报出的行号改 `dts/gk6323v100c-chaoge-z71a.dts`。本地也可先跑：
  `python3 dts/check-dts.py dts/gk6323v100c-chaoge-z71a.dts`。

### 7. 镜像超过 boot 分区上限

- 现象：`boot.img 超过 boot 分区上限，不可刷入`。
- 原因：boot 分区只有 60M，`-C none` 不压缩。
- 处理：确认 `CONFIG_DEBUG_INFO_NONE=y`（关调试符号）；不要临时打开
  其他大体积调试选项。

### 8. `叠加层未生效：CONFIG_ARM_GIC_V3_ITS=n` / `CONFIG_SND_PCM=y` / `CONFIG_SND_TIMER=y`

- 现象：逐行自检报这三条未生效，而它们的实际值是 `y` 或 `m`，与写的不同。
- 原因：它们都是**无 prompt 符号** —— Kconfig 里只有 `config X`，没有提示
  字符串，取值只由 `default` / `select` 决定。fragment 与 `scripts/config`
  都改不动它，**写了必然被 `olddefconfig` 重算**，这条告警属误报。
- 处理：从 `gk6323v100c.config` 里删掉（v6 已删）。想知道它们实际是什么，
  看构建日志里「派生符号报告」一节，该节列出 `ARM_GIC_V3`、
  `ARM_GIC_V3_ITS`、`SND_PCM`、`SND_TIMER`、`SND_HWDEP`、`SND_RAWMIDI`、
  `SND_SOC`、`MDIO_DEVICE` 的真实取值。
- 本地判断办法：`grep -rn -A6 "^config SND_PCM$" --include='Kconfig*' .`
  —— 若输出里没有引号包着的提示字符串，就是无 prompt 符号。

### 9. `CONFIG_HISI_FESTA_PHY` 未生效

- 现象：期望项与逐行自检都报它未生效。
- 原因：三种可能 —— ①被 `if` 包住而父菜单没开；②依赖未满足；③补丁库更新
  后它被改名或删除。自检现在会自动打印该符号在本次内核树里的 Kconfig 定义，
  看 `depends on` 一行即可区分。
- 处理：
  1. 若打印出 `depends on ...`，按依赖补父项符号（`PHYLIB`、
     `NET_VENDOR_HISILICON`、`OF_MDIO` 等）；
  2. 若打印「找不到该符号的 Kconfig 定义」，说明它被改名了 —— 按补丁库最新
     的 `drivers/net/phy/Kconfig` 或 `drivers/net/mdio/Kconfig` 里的实际
     符号名，改 `gk6323v100c.config` 与 workflow；
  3. 网口相关的三项要一起在：`HISI_FEMAC`（MAC）、`MDIO_HISI_FEMAC`
     （MDIO 总线，对应设备树 `mdio@f9c31100`）、`HISI_FESTA_PHY`（PHY）。
- 注意：网口不影响内核启动，这一条只决定「网口能不能通」。

### 10. 补丁库更新后报 `版本不匹配`

- 现象：`版本不匹配：期望 7.4-rcX，实际 ...`。
- 原因：补丁库 `baseline` 里的 `KERNEL_VERSION` 与 `BASE_SHA` 必须配套。
- 处理：流水线现在**自动读补丁库的 `baseline`**，正常情况不必手工改
  workflow；若仍报不匹配，说明补丁库这两个值自身不配套，找补丁库作者确认。

---

## 二、刷写与启动阶段

### 0. 刷完红灯循环重启（已发生过一次）

- 现象：刷入内核后机器红灯常亮、十几秒一循环地重启。
- 原因：用的板级设备树是**海思 A53 + GIC-400** 那一支，而真机是
  **A55 + GICv3**。内核按 `arm,gic-400` 的地址去初始化中断控制器，
  硬件那里却是 GICv3，early init 直接失败，随后靠 SP805 看门狗复位。
- 处理：
  1. 用救砖包（HiTool 只勾 `boot.img` 与 `dtbo.img`）刷回原版；
  2. 确认新内核配套的 dtb 是 `dts/gk6323v100c-chaoge-z71a.dts` 编出来的
     （含 `cortex-a55` / `gic-v3`）；
  3. 刷写时 dtb 一定要写进 `/dev/mmcblk0p10`。
- 自查：`sudo bash scripts/check-board-dtbo.sh`，应打印
  `goke,gk6323v100c` / `arm,cortex-a55` / `arm,gic-v3`。

### 1. TTL 一个字都没有

- 原因：DTB 没换（dtbo 分区还是旧的），或写错分区。
- 处理：重写 dtbo 分区；核对 `boot = p15`、`dtbo = p10`。

### 2. 出 `Booting Linux` 后停住

- 原因：外设时钟或 eMMC 未就绪。本版把外设时钟改指 fixed-clock，实际
  时钟由 bootloader 保持上电；若引导器没把 SD/eMMC 时钟打开，eMMC 起不来。
- 处理：确认 `bootargs` 里有 `clk_ignore_unused`；把完整串口日志发出来，
  按停在哪一行判断是 eMMC 还是网口。

### 3. 起来了但 USB 声卡不出声

- 现象：插上 USB 声卡，`cat /proc/asound/cards` 没有它。
- 检查顺序：
  1. `lsmod | grep snd_usb_audio` —— 模块加载了吗；
  2. `ls /lib/modules/$(uname -r)/kernel/sound/usb/` —— 模块在不在；
  3. `lsusb -t` —— Audio 接口的 Driver 是不是 `snd-usb-audio`；
  4. `dmesg | tail -40` —— 有没有 `snd-usb-audio` 的报错。
- 常见原因：**刷了内核但没解模块**（或先刷内核后装模块）。按
  `docs/build-and-flash.md` 的顺序重做一次。

### 4. 上不了网

- 检查：`ip link` 有没有 `eth0`；`dmesg | grep -iE "femac|mdio|phy"`。
- 原因：板载网口要三样齐 —— MAC（`HISI_FEMAC`）、MDIO 总线
  （`MDIO_HISI_FEMAC`，对应设备树 `mdio@f9c31100`）、PHY
  （`HISI_FESTA_PHY`），分别依赖 `NET_VENDOR_HISILICON`/`PHYLIB`、`OF_MDIO`。
  少 MDIO 总线时的现象很有特色：`eth0` 存在，但始终没有 link。
- 处理：确认 `NET_VENDOR_HISILICON=y`、`PHYLIB=y`、`OF_MDIO=y`、
  `HISI_FEMAC=y`、`MDIO_HISI_FEMAC=y`、`HISI_FESTA_PHY=y` 都在。

### 5. 设备树 model 不对

- 现象：`verify-device.sh` 报"设备树 model 不是本机型"。
- 原因：dtbo 分区没写新 dtb，或写的是海思那支。
- 处理：`sudo dd if=gk6323v100c-chaoge-z71a.dtb of=/dev/mmcblk0p10 bs=1K conv=fsync && sync && reboot`。

---

## 三、关于救砖

- 手上有完整救砖包（分区表 XML + 各分区 img）时，走 HiTool 网口烧写：
  芯片选 `Hi3798MV310`，**只勾 `boot.img` 与 `dtbo.img`**，别碰
  `fastboot` / `bootargs` / `atf` / `trustedcore`。
- 刷完断电等 20～30 秒再上电。
- 每次只改一处再刷，日志才有对照价值。
