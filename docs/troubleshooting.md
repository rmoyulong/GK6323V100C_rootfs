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
- 仍不够时看流水线报告：**只统计进 Image 的部分**（`built-in.a` 成员 + `vmlinux`
  各段），模块对象已排除在外。⚠️ 别再照 `find . -name '*.o'` 的旧清单裁剪 ——
  它把模块的 `.o` 也算进来了（排最前的 `snd-usb-audio.o` 548KB、`snd-pcm.o`、
  `ntfs3.o` 全是模块），而 Image 里只装 `=y` 的代码，照着它下刀必然打空，
  2026-11-19 那轮就是这么白干一遍的。

### 17. 两处最容易看漏的体积大头（2026-11-19 定位）

- **`CONFIG_RC_CORE`（红外遥控）**：`drivers/media/Kconfig` 第一行注释写明
  *CEC and Remote Controller support should not depend on MEDIA_SUPPORT*，
  `source "drivers/media/rc/Kconfig"` 在 `if MEDIA_SUPPORT` **之前**。
  所以关掉 `MEDIA_SUPPORT` **不会**关掉它，`drivers/media/rc/keymaps/` 那 940KB
  照样在编。要关它必须显式写 `# CONFIG_RC_CORE is not set`（已加进 slim.config 第 14 节）。
- **`CONFIG_KALLSYMS`（内核符号表）**：约 1.8MB，是单笔最大的内置开销。
  但它在 `init/Kconfig` 里的定义是
  `bool "Load all symbols for debugging/ksymoops" if EXPERT` ——
  **必须先开 `CONFIG_EXPERT=y`**（已加进功能层），否则它没有提示字符串，
  裁剪层那句会被 `olddefconfig` 丢弃、自检报「未生效」。
  注意区分：`arch/Kconfig` 里那句 `select KALLSYMS` 属于 `config KPROBES`，
  而 KPROBES 已被裁掉，所以 KALLSYMS 并没有被无条件锁死。代价是 oops 里
  不再打印函数名，需要用 `System.map` 手工解析地址。

---

### 18. 停在「内置命令行与早期控制台自检」，只打了 earlycon / console 两行就 `exit code 1`

现象（2026-11-19 真机日志）：

```
OK   CMDLINE_FORCE=y，内置命令行 424 字节
     （不加 mem= 限制：真机内存 2GiB，见设备树 memory 节点）
     earlycon earlycon=pl011,mmio32,0xf8b00000,115200n8
     console console=ttyAMA0,115200n8
Error: Process completed with exit code 1.
```

本该打印 8 行（`earlycon console clk_ignore_unused root rootfstype rootwait panic
blkdevparts`），却停在第三行之前。

- 原因：与第 11 条同源，触发点是**无值标志**。回显写成
  `v="$(grep -oE "…${k}=…" <<< "$CMDLINE_ARGS" | head -1 | sed …)"`，而
  `clk_ignore_unused`、`rootwait` 这类没有 `=` 的参数让 `grep` 必然零匹配、返回 1；
  步骤开着 `set -euo pipefail`，这条赋值即被判失败，`set -e` 当场杀掉整个步骤 ——
  不打警告、不打诊断，日志里只剩一句 `exit code 1`。
- 同一坑还埋在三处，这次只是恰好都命中了：`DTS_FILE`（`ls … | grep -v …` 零匹配）、
  `DTS_BA`（dts 里没有 `bootargs` 时）、`MEM_REG`（没找到 memory reg 时）——
  后两处一旦失败，紧跟着的「不一致告警」「请人工确认内存节点」就永远打不出来。
- 处理（v17 已做）：四处一律补 `|| true`；新增**「工作流静态自检」**步骤，凡赋值语句
  的命令替换里"管道后紧跟 `grep` / `head`"而末尾没有兜底的，**直接中止并打印行号**。
  该检查用 `\|[[:space:]]+(grep|head)` 精确匹配真管道，正则里的 `|`（后面不跟空格）
  不会被误伤，`od … | tr …` 这类不会零匹配的写法也不受影响。
- 自查手法：本地 `set -euo pipefail` 下跑
  `A="x clk_ignore_unused y"; v="$(grep -oE "clk_ignore_unused=[^ ]*" <<< "$A" | head -1)"`，
  退出码即 1；末尾加 `|| true` 后为 0。

### 19. 设备树体积诊断打出 GB 级数字，或被「内存超过 1024 MiB」拦下（2026-11-19 定位）

现象（2026-11-19 真机日志，dtb 总共才 3880 字节）：

```
  ├─ 保留内存表 : 939524056 字节
  ├─ 结构块 : 2483879936 字节
  └─ 字符串块 : 1543569408 字节
Error: 设备树声明的内存 2048 MiB 超过本机实测的 1024 MiB
```

**这是诊断脚本自身的两个 bug，设备树没有问题**：

- 根因一（字节序读反）：FDT/DTB 是**大端**格式，而诊断用 `od -t u4` 默认按主机字节序
  （x86 为小端）读，把 `off_dt_struct` 的真值 `0x38`(56) 读成 `0x38000000`(939524096)，
  减去 40 之后正好得到日志里的 `939524056`。修法：所有头字段改用 `od --endian=big -t u4`。
- 根因二（内存误判）：拦截拿的是 U-Boot 打印的 `DRAM: 1 GiB`，那是 U-Boot **自己启动时的
  可映射窗口**，不是整机物理内存。真机 `hwinfo/hw1.txt` 的 `memory@0 = 0x80000000`（2GiB）
  与 `hwinfo/hw2.txt` 的 `MemTotal: 2018984 kB` 才作数。修法：判据改为与 2GiB 比对，
  不一致**只告警、不中止**。
- 另加 FDT 完整性校验：魔数必须是 `d00dfeed`、头里的 `totalsize` 必须等于文件大小、
  各块偏移+大小不得越界；不满足先报"文件损坏"，绝不拿错乱数字继续往下判断。
- 自查手法：真机 dtb 的头字段真值约为 `off_dt_struct=0x38`、`off_mem_rsvmap=0x28`、
  `size_dt_struct` 几千字节；若读出来是 `0x38000000` 这种量级，就是字节序反了。


## 二、刷写与启动阶段

### 0. 刷完红灯循环重启

- 2026-11-18 那次的实际原因是**镜像超过 U-Boot 的 `CONFIG_SYS_BOOTM_LEN`**，
  不是设备树 —— 日志里 U-Boot 明说 `Image too large: increase CONFIG_SYS_BOOTM_LEN`、
  随即 `Must RESET board to recover`。详见第 6 条。
- 设备树认错芯片（拿海思 A53 + GIC-400 的树去启动本机的 A55 + GICv3）确实也会
  在 GIC 初始化阶段失败并复位，但那一次日志里没有这条症状；若日后遇到，
  用救砖包刷回，并核对 dtb 是否来自 `dts/gk6323v100c-chaoge-z71a.dts`。
- 自查：`sudo bash scripts/check-board-dtbo.sh`，应打印
  `goke,gk6323v100c` / `arm,cortex-a55` / `arm,gic-v3`。

### 1. TTL 一个字都没有（2026-11-19 复核：首要嫌疑是漏刷 `p10`）

现象：U-Boot 段一切正常，接着是

```
## Booting kernel from Legacy Image at 04000000 ...
   Loading Kernel Image ... OK
ATAGS [0x00000100 - 0x000005E0], 1248Bytes

Starting kernel ...

Start ATF with aarch64 kernel...
INFO:    BL31 Early setup
NOTICE:  BL31: v2.0(debug):b05835d-dirty
INFO:    BL31: Preparing for EL3 exit to normal world
INFO:    Entry point address = 0x2000000
INFO:    SPSR = 0x3c5
```

之后串口再无任何输出，**也不复位**（注意与红灯循环区分开）。

**2026-11-19 复核结论：首要嫌疑是只刷了 `p15`、漏刷 `p10`。**
- arm64 内核只能从 `x0` 收设备树 —— `arch/arm64/kernel/head.S` 里
  `mov x21, x0`（注释即 "x0 = physical address to the FDT blob"），
  `setup.c` 再用 `setup_machine_fdt(__fdt_pointer)` 校验；
  **arm64 没有 arm32 那种 `ARM_APPENDED_DTB` / `ARM64_APPENDED_DTB` 配置项**，
  也没有任何"从 Image 末尾自己翻 dtb"的代码，所以"内嵌 dtb"在 arm64 上**不起作用**。
- 日志里打的是 `ATAGS [...]` 而不是 `using: FDT`，正是"内核没走 FDT 路径"的信号。
- 作者原厂 `boot.img` 里**也没有**追加 dtb：在其中搜到的那个 `d00dfeed`，
  其 `totalsize` 只有 131 字节，是不合法的巧合字节（误报）。作者的设备树来自
  `dtbo` 分区 —— 他的 `dtbo.img` 开头就是 `d00dfeed`，`totalsize` 9156 字节。
- 本仓库 `scripts/flash-boot.sh` 的 `-d` 参数说明写着「真机用的是 dtbo 分区里的 dtb，
  不是内嵌那份」，README 第五节也把"刷设备树"列为**必须步骤**。
  **刷内核时必须一并写 `p10`**（或直接用 `flash-boot.sh -d <dtb>`），漏了这一步，
  内核等于没有设备树。

这一串其实说明了两件好事：镜像大小过关（U-Boot 收下了），ATF(BL31) 也把控制权
交给了内核（`Entry point address = 0x2000000` 与 uImage 头的 `Load/Entry Point:
02000000` 一致）。坏消息是内核侧一行都没有 —— 而 arm64 内核在拿到**合法设备树**
之前不会建立任何 console，所以这一类十有八九是**内核没拿到有效 fdt**。

按顺序查：

1. **先看 U-Boot 到底有没有把设备树交给内核。** 本机 `bootcmd` 是
   ```
   mmc read 0 0x08020000 0x10000 0x1000;   # atf 分区 -> 0x8020000
   mmc read 0 0x03FFC000 0x19000 0x20;     # dtbo 分区 16KiB -> 0x03FFC000
   mmc read 0 0x04000000 0x38000 0x7800;   # boot 分区 -> 0x04000000
   bootm 0x04000000
   ```
   注意 `bootm` **没有第三个参数**。legacy uImage 路径下只有
   `bootm <kernel> <initrd|-> <fdt>` 才显式传设备树；只写 `bootm <kernel>` 时，
   U-Boot 用自己 `gd->fdt_blob`，也可能一个都不传。日志里那句 `ATAGS [...]`
   （而不是 `using: FDT`）就是"没走 FDT 路径"的信号 —— arm64 内核不吃 ATAGS，
   校验 magic 失败即挂住，而此时 console 尚未建立，所以串口全静。
   在 U-Boot 里（`Autobooting in 1 seconds` 时按 **Ctrl+C**）执行并把输出留下来：
   ```
   bdinfo
   fdt addr 0x03FFC000
   fdt print /compatible
   fdt print /memory
   fdt print /chosen
   printenv bootcmd bootargs
   ```

2. **显式把设备树传给内核，做一次对照实验。** 下面这组**不写环境变量**，
   断电即失效，不会污染原厂环境：
   ```
   mmc read 0 0x08020000 0x10000 0x1000
   mmc read 0 0x03FFC000 0x19000 0x20
   mmc read 0 0x04000000 0x38000 0x7800
   bootm 0x04000000 - 0x03FFC000
   ```
   第三个参数 `-` 表示没有 initrd，第四个 `0x03FFC000` 是 fdt 地址。
   - 若这次看到内核输出了 → 根因就是"没传 fdt"，再固化：
     ```
     setenv bootcmd 'mmc read 0 0x08020000 0x10000 0x1000; mmc read 0 0x03FFC000 0x19000 0x20; mmc read 0 0x04000000 0x38000 0x7800; bootm 0x04000000 - 0x03FFC000'
     saveenv
     ```
   - 若仍然全静 → 问题更早（ATF 传参或内存），把第 1 步几条的输出发出来再定。

3. **dtbo 分区写的必须是本仓库的 dtb。** 内核用的 fdt 若来自 dtbo 分区，
   只刷 `p15` 不够，`/dev/mmcblk0p10` 也要写。

4. **内存节点必须等于真机值 `0x80000000`（2GiB）。** 依据是真机导出设备树
   （`hwinfo/hw1.txt`）的 `memory@0`，与真机 `/proc/meminfo` 的
   `MemTotal: 2018984 kB` 吻合。★ 别照 U-Boot 打印的
   `DDR Size: 1 GiB (Boot: 1 GiB)` 写 —— 那是 U-Boot 自己的可映射上限，不是
   硬件容量。写小了白白少认一半内存；写大了内核会遍历并不存在的物理页，
   同样在 console 建立之前挂住。流水线会把它与真机值（2GiB）比对，不一致时告警；
   ★ **不做中止** —— 2026-11-19 那次正是拿 U-Boot 的 1 GiB 当上限，误杀了正确的
   2GiB 配置（详见构建阶段第 19 条）。

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
