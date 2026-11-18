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

### 9. `CONFIG_HISI_FESTA_PHY` 未生效（已定位：符号已不存在）

- 现象：期望项与逐行自检都报它未生效。
- **已确认的原因**：补丁库 rc3 版重构清单后，整库 126 个补丁里已没有任何 Festa
  PHY 驱动补丁（旧库那个 `pending-7.4/210-01-...-festa-phys.patch` 在重构后消失），
  所以 7.4-rc3 内核树里根本没有 `HISI_FESTA_PHY` 这个符号。本文件已不再写它。
- 判别「符号不存在」与「只是被关掉」：
  - 符号存在于树里：即使关掉，`.config` 里也会有 `# CONFIG_XXX is not set` 一行；
  - 一行都没有：树里没这个符号，写进叠加层必然被 `olddefconfig` 丢弃。
- 处理：网口三项里 `HISI_FEMAC`（MAC）与 `MDIO_HISI_FEMAC`（MDIO 总线，对应设备树
  `mdio@f9c31100`）保留；PHY 一侧等驱动回到补丁库再补，或改用 `hisi-femac` 自带
  的 PHY / 固定链路方案。流水线的「已移除符号报告」一节会持续盯住它。
- 注意：网口不影响内核启动，这一条只决定「网口能不能通」。

### 10. 补丁库更新后报 `版本不匹配`，或基线没跟着库走

- 现象：`版本不匹配：期望 7.4-rcX，实际 ...`；或库里升了版本，构建仍按旧版本进行。
- 原因：补丁库 `baseline` 用的是 make 写法（`KERNEL_VERSION := 7.4-rc3`），只认
  `=` 的正则会在它上面取到**空串**，于是静默回落到 workflow 里写死的兜底值 ——
  「自动读基线」形同失效，库换版本也不会跟着动。
- 处理：流水线已改为同时认 `=` 与 `:=`。若仍报不匹配，说明补丁库这两个值自身
  不配套，找补丁库作者确认。

### 11. 检查步骤「无声」退出：日志停在某一项，只有 `exit code 1`

- 现象：日志停在「期望项」或「逐行自检」的某一行，没有警告、没有诊断，直接
  `Process completed with exit code 1`。
- 原因：这些步骤开着 `set -euo pipefail`。写成 `CUR="$(grep … | head -1)"` 时，
  若该符号在 `.config` 里一行都没有，`grep` 返回 1、`pipefail` 把整条管道带成
  非零，这个赋值命令就失败，`set -e` 立刻杀掉整个步骤 —— 于是什么都不打印。
- 处理：流水线已把从 `.config` 取值统一收进 `lookup()`（无命中返回空串、不返回
  非零），并新增「一行都没有」的专门提示。同类问题再出现时，日志会明确写出是
  「符号不在内核树中」还是「只是被关掉」。

### 12. 补丁库布局变了：没有 `series` 文件

- 现象：日志打印「未找到 series 文件，按文件名序号应用根目录下全部补丁」，补丁
  总数与以往不同。
- 原因：补丁库 rc3 版把补丁改为平铺在仓库根、重新编号（`NNN[-SS]-shortname`），
  不再有分桶目录。应用脚本对两种布局都支持：有 `series` 按 `series`，没有就按
  文件名 `sort -V` 全量应用。
- 处理：脚本不必改。但「全量应用」意味着 9xx 的 bring-up／插桩补丁也会被打上；
  若不想把调试内容带进产物，应在补丁库侧用 `series` 明确列出要用的补丁。

### 13. 一堆 `Value of CONFIG_xxx is redefined by fragment ...`，最后只报 `exit code 1`

现象（2026-11-19 真机日志）：先是若干条

```
Value of CONFIG_NTFS3_FS is redefined by fragment ../slim.config:
Previous value: # CONFIG_NTFS3_FS is not set
New value: CONFIG_NTFS3_FS=y
```

紧跟着 `.config:12076:warning: symbol value 'n' invalid for FRAME_WARN`，再一句
`yes: standard output: Broken pipe`，最后 `Process completed with exit code 1`，
后面的检查一节全都没跑。这其实是**两件事叠在一起**：

- `redefined` **不是错误**，是 `merge_config.sh` 的正常提示 —— 两个 fragment 都写了
  同一个符号，后者覆盖前者。但它暴露出真问题：**两个配置层在抢符号**。那批里
  `NTFS3_FS`、`FB`、`MSDOS_FS`、`NLS_CODEPAGE_437`、`DEBUG_INFO_NONE` 都是这种，
  谁生效只取决于文件顺序，肉眼看不出来。
- `exit code 1` 与配置内容无关，是**脚本自杀**。本步骤开着 `set -o pipefail`，
  而 `make olddefconfig` 是非交互的、根本不读 stdin；写成
  `yes "" | make … olddefconfig` 时 make 先退出，`yes` 收到 SIGPIPE，
  整条管道返回非零，`set -e` 立刻杀掉步骤 —— 所以只剩那一句 Broken pipe。
  实测：`set -euo pipefail; yes "" | true` 退出码 **1**；去掉 pipefail 则为 0。

处理（v11 已做）：`olddefconfig` 前去掉 `yes "" |`；新增「配置分层纪律自检」，
功能层出现关闭行、裁剪层出现启用行、或两层符号重叠，都直接中止并打印行号。

### 14. `.config:NNNN:warning: symbol value 'n' invalid for FRAME_WARN`

- 原因：`CONFIG_FRAME_WARN` 是 **int** 型符号，裁剪层却写成
  `# CONFIG_FRAME_WARN is not set`；merge_config 会把它译成
  `CONFIG_FRAME_WARN=n`，Kconfig 拒收。
- 处理：v11 已从裁剪层删掉这一行。以后要调阈值就写数值
  （`CONFIG_FRAME_WARN=2048`），不写就用内核默认（64 位为 2048）。
  同类还有 hex / string 型符号 —— 例如 `CONFIG_CMDLINE` 要靠
  `CONFIG_CMDLINE=""` 这种写法，不能写 `is not set`。

### 15. 裁剪项写进去了却没生效

- 现象：`=== 裁剪层逐行自检 ===` 里出现
  `裁剪未生效：CONFIG_XXX 仍是 y —— 多为被 select 强制拉起，或依赖被拉回`。
- 原因：最常见是被别的已开启符号 `select` 强制拉起 —— 例如
  `WATCHDOG_CORE` 之于 `ARM_SP805_WATCHDOG`；其次是它的父菜单没开，
  写进去也无处落地。
- 处理：自检会把该符号在本次内核树里的 Kconfig 定义打印出来，看
  `select` / `depends on` 那一行就能判断：被 select 拉起的**删掉这行**（改不动），
  父项没开的**先开父项**。
- 特别提醒：**不要关 `CONFIG_WATCHDOG_CORE`**。SP805 看门狗是这颗 SoC 唯一的
  复位通道，panic 后靠它重启；把它连带关掉会很难查。

### 16. 想继续压体积，该看哪里

- 先看 Release 里的 `config-7.4.*`（本次真正生效的 .config）：**只关 `=y` 的项**，
  `=m` 的驱动对 Image 体积零贡献。
- 再看流水线两节报告：「裁剪层逐行自检」告诉你哪些还没关上；「体积构成」列出
  最大的 30 个内置 `.o` 与各顶层目录占用，直接指出下一刀该砍在哪。
- 已知大头（arm64 默认配置里都是 `=y`）：53 个 `ARCH_*` 平台、`ACPI`、`PCI`、
  `KVM`/`XEN`/`VIRTUALIZATION`、`IPV6`、`NETFILTER`、`ATA`、`MD`、`NFS_FS`、
  `SQUASHFS`、`FB`、`BPF_SYSCALL`、`MEMCG`/`BLK_CGROUP`、`KEXEC`、
  `TEE`/`OPTEE`、`STAGING`、`HIBERNATION`、`KALLSYMS_ALL` —— v11 的
  `slim.config` 已把这一批关掉。
- 仍不够时的下一批候选：`KALLSYMS` 本体（会失去 oops 函数名解析，带板阶段不划算）、
  用不到的 `CRYPTO` 算法、`SOUND` 里的非 USB 部分。

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
  `HISI_FEMAC=y`、`MDIO_HISI_FEMAC=y` 都在。PHY 一侧：补丁库 rc3 起内核树里
  已没有 `HISI_FESTA_PHY` 符号（见构建阶段第 9 条），若网口因此拿不到 link，
  需等驱动回到补丁库，或改用固定链路方案。

### 5. 设备树 model 不对

- 现象：`verify-device.sh` 报"设备树 model 不是本机型"。
- 原因：dtbo 分区没写新 dtb，或写的是海思那支。
- 处理：`sudo dd if=gk6323v100c-chaoge-z71a.dtb of=/dev/mmcblk0p10 bs=1K conv=fsync && sync && reboot`。
- **设备树体积：已核实不是瓶颈，但流水线仍每轮打印**。`bootcmd` 里从 dtbo 分区
  读的是 `0x20` = 32 块 = **16KiB** 到 `0x03FFC000`（正好顶到内核加载地址
  `0x04000000` 之前）；作者那版 dtbo 里的 dtb 是 **9156 字节**。
  本地按 dtb 规范逐字节核算本仓库的 dts：**未精简版约 7100 字节**（带 `-@`
  约 8060），**精简版约 3800 字节** —— 只占 16KiB 窗口的 **23%**，余量充足。
- ⚠️ 别被 Release 列表里那个 **"28.24 KB"** 误导：那是页面上相邻字段
  （文件名 + 哈希 + 大小）粘连显示的结果，与这份 dts 编出的 dtb 无关
  （同一列表里 `boot.img` 也显示成 "1 MB"、`config` 显示成 "1322 KB"，都不合理）。
  以 `sha256sums.txt` 的记录，或构建日志「设备树体积诊断」一节为准。
- 流水线现在会打印 dts 字节数、dtb 字节数、窗口占用百分比与节点数；
  **dtb 超过 16KiB 直接中止**，不会产出会被截断的 dtb。真要超了，第一次序是删
  dts 里无消费者的节点（`gpio`×8、未用的 `uart2`/`uart3`、`i2c0`/`i2c1`、`spi0`），
  并确认没有给 dtc 加回 `-@`（`-@` 会白白生成 `__symbols__`，多占约 900 字节）。

### 6. 内核根本没加载：U-Boot 报 `Image too large: increase CONFIG_SYS_BOOTM_LEN`

- 现象：TTL 日志里反复出现同一段，**看不到任何内核输出**：
  ```
  ## Booting kernel from Legacy Image at 04000000 ...
     Loading Kernel Image ... Image too large: increase CONFIG_SYS_BOOTM_LEN
  Must RESET board to recover
  resetting ...
  ```
  然后红灯、十几秒一轮循环。
- 判读要点：**这不是"日志抓漏了"**。`Image too large` 出现在 U-Boot 阶段，
  内核压根没被跳转，所以自然没有任何 `Booting Linux`、earlycon 输出。
- 原因：`bootm` 跳转内核前，拿 uImage 的数据大小（`ih_size`）与它编译时的
  `CONFIG_SYS_BOOTM_LEN` 比较，超了就拒绝。实测到两个边界：
  - 作者原厂 `boot.img` = **14,028,808 字节**（`ih_size` 14,028,744）能启动
    → 上限 ≥ 13.38MiB；
  - 本仓库上一版约 15MB 的镜像被同一台机器拒绝 → 上限 < 15MB。
  故真实上限落在 (13.38MiB, 15MB) 之间，最可能是 **14MiB（0xE00000）**。
  另外 `bootcmd` 里 `mmc read ... 0x7800` 一次只读 30720 块 = 15MiB，
  读窗口也在同一条线上。
- 与「boot 分区 60M」是两个不同的限制，别混：前者是写不写得进，
  后者是 U-Boot 收不收。
- **为什么 hi3798mv100 的"8M uImage"救不了这一局**：mv100 是 arm32，
  uImage 里装的是 `make zImage` 的产物 —— 自带解压头、内核本体用 XZ 压缩
  （那个仓库的 `kernel.config` 里 `CONFIG_KERNEL_XZ=y`），所以 U-Boot 只看到
  压缩后的 8~9MB；本机是 arm64，`make Image` 产出的既无解压头也不压缩，
  U-Boot 看到的是全量。体积差来自**镜像形态**，不是配置精瘦程度 ——
  照搬 mv100 的配置也不会变小。
- **`mkimage -C gzip` 同样绕不过去**：`bootm` 的 gzip 分支把
  `CONFIG_SYS_BOOTM_LEN` 当作解压输出缓冲上限，解压后的 `Image` 仍须 ≤ 该值。
- 处理：在 **`slim.config`**（裁剪层，只写 `# CONFIG_XXX is not set`）里继续关掉
  无关子系统、重建 —— v11 起所有裁剪项都已从 `gk6323v100c.config` 搬到该文件。
  流水线会在打包步骤打印 `ih_size`、`size vmlinux`、**最大的 30 个内置 `.o`**
  与顶层目录占用，照那份清单接着砍即可。
  关键认识：Image 里只装 `=y` 的代码，编成 `=m` 的驱动对 Image 体积**零贡献**
  （模块放在 rootfs 上，没有大小限制），所以"能模块化的就模块化"最有效；
  arm64 默认配置把二十多个 SoC 平台全部内置、平台驱动又不能模块化，
  那才是大头。
- 流水线已加硬校验：`ih_size` 超过 `BOOT_IMAGE_MAX_MB`（本版起为 **13MiB**）
  就中止，**不发布刷进去会变砖的镜像**。
- 救砖照走「三、关于救砖」。

---

## 三、关于救砖

- 手上有完整救砖包（分区表 XML + 各分区 img）时，走 HiTool 网口烧写：
  芯片选 `Hi3798MV310`，**只勾 `boot.img` 与 `dtbo.img`**，别碰
  `fastboot` / `bootargs` / `atf` / `trustedcore`。
- 刷完断电等 20～30 秒再上电。
- 每次只改一处再刷，日志才有对照价值。
