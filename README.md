# GK6323V100C 内核（USB 声卡支持）—— 构建与刷写

面向国科微 GK6323V100C 机顶盒（整机型号 ChaoGe Z71A）的自编译 ARM64 内核。
产物形态与 [hi3798mv100 仓库](https://github.com/rmoyulong/hi3798mv100) 一致：
**一个内嵌设备树的 uImage 内核 + 一份内核模块**。

---

## 一、先说清楚：这台机器不是海思 MV200H

早前把 GK6323V100C 当成"硅片等同海思 Hi3798MV200H（4×A53 + GIC-400）"，
这个判断是**错的**。数据取自真机运行中的原厂内核（真机导出的设备树 +
`/proc/cpuinfo`）：

| 项目 | 真机 GK6323V100C（本仓库目标） | 海思 Hi3798MV200H（此前误判） |
| --- | --- | --- |
| 根 compatible | `chaoge,z71a` / `goke,gk6323v100c` | `hisilicon,hi3798mv200` |
| CPU | 4×`arm,cortex-a55`（part 0xd05） | 4×`arm,cortex-a53` |
| 中断控制器 | `arm,gic-v3`（GICD 0xf1000000 / GICR 0xf1040000） | `arm,gic-400` |
| PSCI | `arm,psci-0.2` | `arm,psci-1.0` |
| 时钟/复位 | `goke,gk6323v100c-cru`（国科私有） | `hisilicon,hi3798mv200-crg` |
| 内存 | 2 GiB（真机 MemTotal 2018984 kB） | 机型而异 |

外设 IP 地址确实相像（UART `f8b00000`、eMMC `f9830000`、网口 `f9c30000`、
USB `f9880000`/`f9890000`），但 **CPU 核与中断控制器是根本性不同**，
拿海思 A53 的板级设备树去启动，GIC 初始化必然失败，表现就是**红灯循环重启**。

所以本仓库的板级设备树是**自己写的**：`dts/gk6323v100c-chaoge-z71a.dts`，
逐项取自真机，不套用海思的 `hi3798mv200h` 板级。

---

## 二、与 hi3798mv100 的差别（只有 5 处）

流程、目录骨架、产物命名、刷写顺序都与 mv100 那套同构，实质差别如下：

| 项目 | hi3798mv100 | 本仓库 |
| --- | --- | --- |
| 架构与工具链 | `ARCH=arm` | `ARCH=arm64`，`aarch64-linux-gnu-` |
| 内核镜像 | `zImage`（XZ压缩）→ `-A arm` uImage | `Image`（无压缩）→ `-A arm64` uImage |
| 设备树 | 类同做法，追加到镜像末尾 | 追加到 `Image` 末尾，另单独发一份 |
| 单板配置 | `kernel.config`（整份） | 功能配置 `gk6323v100c.config` + 体积裁剪 `slim.config` 两层叠加 |
| 刷写分区 | `boot` | `boot = /dev/mmcblk0p15`，另有 `dtbo = /dev/mmcblk0p10` |

---

## 三、产物

| 文件 | 用途 | 落到哪 |
| --- | --- | --- |
| `boot.img` | uImage 内核，设备树追加在镜像末尾 | `/dev/mmcblk0p15`（60M） |
| `gk6323v100c-chaoge-z71a.dtb` | 设备树 | **必须**写 `/dev/mmcblk0p10`（2M，dtbo） |
| `modules.tar.gz` | 内核模块 | 解到 `/` |
| `Image` | 裸内核，仅核对用 | 不刷 |
| `config-7.4.*` | 实际使用的内核配置 | 不刷 |
| `sha256sums.txt` | 上述产物的校验值 | 不刷 |

**为什么 dtb 必须单独写 dtbo 分区**：真机运行时用的设备树来自 dtbo 分区
（作者原 `boot.img` 内并没有内嵌 dtb）。内嵌的那份是冗余备份；漏写 dtbo
等于没换设备树，新内核照样起不来。

---

## 四、构建

推到自己的 GitHub 仓库后：

1. Settings → Actions → General → Workflow permissions 选 **Read and write**。
2. Actions 里选「GK6323V100C 内核自动构建」→ Run workflow。
3. 也可以在改动 `gk6323v100c.config`、`slim.config`、`apply_histb_patches.sh`、`dts/*.dts`
   或本workflow时自动触发。

> **配置分层说明（两层职责必须分清）**：
> `gk6323v100c.config` = 功能层，**只写「要打开什么」**（`CONFIG_X=y` / `=m` / `="串"`）；
> `slim.config` = 裁剪层，**只写「要关掉什么」**（`# CONFIG_X is not set`）。
> 合并顺序：`defconfig` → 功能层 → 裁剪层 → `olddefconfig`，裁剪层必须在功能层之后。
>
> 流水线的**「配置分层纪律自检」**把这条钉死，违反即中止构建：裁剪层出现
> `=y`/`=m`、功能层出现 `# … is not set`、或两层写了**同一个符号**，都会直接
> 报错并打印行号。2026-11-19 那次失败正是两层互抢 `CONFIG_NTFS3_FS`、
> `CONFIG_FB`、`CONFIG_MSDOS_FS`、`CONFIG_NLS_CODEPAGE_437`、
> `CONFIG_DEBUG_INFO_NONE`，谁生效只取决于文件顺序。
>
> 想继续压体积时：从 Release 下载 `config-7.4.*`（本次实际生效的 .config），
> 在里面搜到想关的符号、**确认它是 `=y`**，再往 `slim.config` 加一行即可 ——
> 不必改 workflow，也不必动功能层。`=m` 的项不用关：模块不进 Image，
> 对 U-Boot 那道体积上限零贡献。

流水线里会做这些把关：设备树静态校验（漏分号 / label 未定义 / 节点地址与
reg 不符）→ **从补丁库 baseline 自动读取内核版本与基线 commit** → 内核版本与
补丁基线核对 → 配置必须项硬校验 → 设备树追加处魔数必须是 `d00dfeed` →
编译后的 dtb 反编译回读，确认含 `cortex-a55`、`gic-v3`、`pl011`、
`snps,dw-mshc`、`gk6323v100c` → **dtb 体积必须 ≤ 16KiB**（超出即中止，因引导器
只读 32 块）→ 镜像体积两道关都过（写不写得进 60M 分区、
`ih_size` 是否在 U-Boot 的 `CONFIG_SYS_BOOTM_LEN` 之内，详见「已知限制」）。

补丁库更新后**不必再改 workflow**：`KERNEL_VERSION` 与 `BASE_SHA` 以补丁库的
`baseline` 文件为准（`=` 与 `:=` 两种写法都认），workflow 里写的那两个值只是
补丁库缺该文件时的兜底。

配置自检分四节，含义不同，别混看：

| 小节 | 判什么 | 没通过意味着什么 |
| --- | --- | --- |
| 配置分层纪律自检 | 两层是否各守本分、有没有抢同一个符号 | **直接中止构建**，并打印违规行号 |
| 必须项 | 少一项这台机器就起不来或目标落空 | **直接中止构建** |
| 期望项 | 功能相关符号是否生效 | 只告警；会自动打印该符号的 Kconfig 定义，并区分「只是被关掉」与「内核树里没这个符号」 |
| 已移除符号报告 | 补丁库已不再提供的符号（如 `HISI_FESTA_PHY`）在树里是否存在 | 仅报告，不中止 |
| 派生符号报告 | 无 prompt 符号（`SND_PCM`、`SND_TIMER`、`ARM_GIC_V3_ITS` 等）的实际取值 | 仅报告。这类符号写进叠加层也改不动，所以叠加层里根本不写 |
| 单板配置层逐行自检 | 功能层每一行是否真的落到最终 `.config` | 只告警；`=m` 行按 `[ym]` 判定（被 select 提升为 y 属正常） |
| 裁剪层逐行自检 | 裁剪层每一行是否真的关上了 | 只告警；区分「仍是 y/m（多为被 select 拉起）」与「内核树无此符号」两种情形 |

四个已经踩过、已经修掉的坑：

- **`yes "" | make … olddefconfig` 会让整个步骤自杀**。步骤开着 `set -o pipefail`，
  而 `olddefconfig` 是非交互的、根本不读 stdin：make 先退出，`yes` 随即收到
  SIGPIPE，整条管道返回非零，`set -e` 立刻杀掉步骤 —— 日志里只有
  `yes: standard output: Broken pipe` 和 `exit code 1`，后面的检查一个字都没跑。
  v11 已删掉这段管道。实测 `set -euo pipefail; yes "" | true` 退出码 1，
  去掉 pipefail 为 0。
- 自检取值统一走 `lookup()`。此前写成 `CUR="$(grep … | head -1)"`，一旦某符号在
  `.config` 里一行都没有，`set -euo pipefail` 会让整个步骤**静默退出**，日志只剩
  `exit code 1`，既没有告警也没有诊断。
- 补丁库 `baseline` 是 make 写法（`KERNEL_VERSION := 7.4-rc3`）。只认 `=` 的正则会
  取到空串、静默回落到兜底值，「自动读基线」形同失效；现在两种写法都认。
- **取值处漏了 `|| true` 兜底**。2026-11-19 那次停在「内置命令行与早期控制台自检」：
  只打了 `earlycon` / `console` 两行就 `exit code 1`。`clk_ignore_unused`、`rootwait`
  是**无值标志**，回显用的 `grep -oE "…${k}=…"` 对它们必然零匹配、返回 1，
  `pipefail` 把这条赋值判成失败，`set -e` 当场杀掉步骤。同一坑还在设备树
  `bootargs` 比对、内存节点提取处。现四处一律补 `|| true`，并新增
  **「工作流静态自检」** 步骤：凡"赋值 + 管道 `grep`/`head`"没兜底的，直接中止
  构造并打印行号（只认真管道，不会误伤 `lookup()` 调用与 `od … | tr …`）。

---

## 五、刷写（顺序不可颠倒）

```bash
# 0. 三个文件传到机器 /tmp：boot.img、gk6323v100c-chaoge-z71a.dtb、modules.tar.gz

# 1. 备份原 boot 分区
sudo dd if=/dev/mmcblk0p15 of=/root/boot.bak bs=1M conv=fsync

# 2. 先装模块（内核与模块必须同版本）
cd / && sudo tar -xzf /tmp/modules.tar.gz && sync

# 3. 刷内核
sudo dd if=/tmp/boot.img of=/dev/mmcblk0p15 bs=1M conv=fsync && sync

# 4. 刷设备树 —— 本机型必须这一步
sudo dd if=/tmp/gk6323v100c-chaoge-z71a.dtb of=/dev/mmcblk0p10 bs=1K conv=fsync && sync

# 5. 重启
sudo reboot
```

也可以用仓库里的脚本一次做完（带备份、大小校验、dry-run）：

```bash
sudo bash scripts/flash-boot.sh -i boot.img -m modules.tar.gz \
     -d gk6323v100c-chaoge-z71a.dtb -n      # 先 dry-run 看一遍
sudo bash scripts/flash-boot.sh -i boot.img -m modules.tar.gz \
     -d gk6323v100c-chaoge-z71a.dtb         # 确认无误后真正执行
```

> **只刷 `p15` 不够**：本机 `bootcmd` 是 `bootm 0x04000000`，**没有第三个 fdt 参数**，
> 内核用的设备树很可能取自 dtbo 分区（`p10`），所以 `p10` 要一并写。
> 若串口仍然全静，按 `docs/troubleshooting.md` 第 1 条那组命令，在 U-Boot 里用
> `bootm 0x04000000 - 0x03FFC000` 显式传一次设备树做对照 —— 那是**临时输入、
> 不写环境变量**，断电即失效，不污染原厂参数。

---

## 六、验证

接 TTL 串口（**115200**）看启动日志，按停在哪一步定位：

| 现象 | 说明 | 下一步 |
| --- | --- | --- |
| 一个字都没有，且**不复位** | 内核没拿到有效 fdt（首位嫌疑），或内存节点与实际不符 | 见 `docs/troubleshooting.md` 第 1 条：先在 U-Boot 里 `bdinfo` / `fdt print /memory` / `fdt print /chosen`，再试 `bootm 0x04000000 - 0x03FFC000` 显式传设备树 |
| 红灯循环、TTL 里全是 U-Boot | 镜像超过 `CONFIG_SYS_BOOTM_LEN` | 看本文第八节第一条 |
| 出 `Booting Linux` + earlycon 后停住 | 时钟或 eMMC 未就绪 | 看 troubleshooting「启动阶段」第 2 条 |
| 打印出 mmcblk0 分区表 | eMMC 通了 | 看根文件系统能否挂载 |
| 进到 shell | 第一阶段完成 | 插 USB 声卡，`cat /proc/asound/cards` |

起来后跑：

```bash
sudo bash scripts/verify-device.sh
```

其中会判定设备树是否为 `GK6323V100C / Z71A`、USB 声卡模块是否加载、
`/proc/asound/cards` 是否多出 USB 卡。

---

## 七、回滚

```bash
sudo dd if=/root/boot.bak of=/dev/mmcblk0p15 bs=1M conv=fsync && sync && reboot
```

注意：本次同时改写了 dtbo 分区。回滚内核不会自动恢复原设备树；若手上有
原机 `dtbo.img`，请一并写回 `/dev/mmcblk0p10`。手上没有原 dtbo 时，用
`scripts/restore-stock.sh` 按提示操作。

---

## 八、这一版的已知限制

- **镜像大小有硬上限（最容易踩）**：`bootm` 跳转内核前拿 uImage 的 `ih_size`
  与它编译时的 `CONFIG_SYS_BOOTM_LEN` 比较，超了就打印
  `Image too large: increase CONFIG_SYS_BOOTM_LEN` 并复位 —— 表现是**红灯
  循环重启、TTL 里全是 U-Boot、看不到任何内核输出**。
  实测边界：作者原厂 `boot.img` 14,028,808 字节（`ih_size` 14,028,744）
  能正常启动，本仓库上一版约 15MB 的镜像被同一台机器拒绝
  → 真实上限落在 **(13.38MiB, 15MB)** 之间，最可能是 14MiB（`0xE00000`）；
  另外 `bootcmd` 一次只读 30720 块 = 15MiB，读窗口也在同一条线上。
  本版据此把目标定为 **`ih_size` ≤ 13MiB**，由 `BOOT_IMAGE_MAX_MB` 把关，
  超过即中止，不发布不可刷的镜像。
- **别照抄 hi3798mv100 的体积**：那个仓库是 arm32，uImage 里装的是 XZ 压缩、
  自带解压头的 `zImage`，U-Boot 只看到压缩后的 8~9MB；本机是 arm64，
  `Image` 既无解压头也不压缩，U-Boot 看到的是全量 —— 差别在镜像形态，
  不在配置精瘦程度。`mkimage -C gzip` 也绕不过（gzip 分支把
  `CONFIG_SYS_BOOTM_LEN` 当解压输出上限）。唯一有效的办法是真把 Image 编小：
  Image 只装 `=y` 的代码，`=m` 的驱动对它零贡献，所以"能模块化的就模块化"，
  外加关掉其它 arm64 平台。
- **设备树体积（已核实不是瓶颈）**：`bootcmd` 从 dtbo 分区只读 32 块（16KiB）到
  `0x03FFC000`，作者那版 dtb 是 9156 字节。本地按 dtb 规范逐字节核算本仓库的 dts：
  **未精简版约 7100 字节、精简版约 3800 字节**，只占窗口 **23%**。
  流水线每轮打印 dts/dtb 字节数、窗口占用与节点数，**超过 16KiB 直接中止**。
  ⚠️ Release 列表里那个 "28.24 KB" 是页面相邻字段粘连显示的结果，不是真实大小
  （同一列表里 `boot.img` 也显示成 "1 MB"、`config` 显示成 "1322 KB"，都不合理）——
  以 `sha256sums.txt` 或构建日志的「设备树体积诊断」一节为准。
- **eMMC 依赖 bootloader 已配好的时钟**：国科私有 CRU 没有主线驱动，本版
  把外设时钟改指 fixed-clock 并保持 `clk_ignore_unused`，能否起来取决于
  引导器是否已把 SD/eMMC 时钟打开。这是第一版的最大不确定点。
- **板载 ES8316 音频暂不可用**：它走国科 AIAO 控制器，主线无驱动；本版
  设备树未包含该节点（保留给后续版本）。USB 声卡不受影响。
- **内核版本号是 7.4.x**，不是作者那版 `6.18.46-gk6323-debian`，模块装在
  `/lib/modules/7.4.x`，内核与模块必须一起替换。
- CPU 变频（`goke,gk6323-cpufreq`）、红外、温度传感器同样缺少主线驱动，
  本版未启用（`CPU_FREQ` / `RC_CORE` 已在裁剪层显式关掉，顺便省下体积）。
- **体积把关只认"内置"**：`Image` 里只装 `=y` 的代码，`=m` 的驱动对体积零贡献。
  流水线「体积构成」只统计 `built-in.a` 成员与 `vmlinux` 各段，模块对象单列；
  别再照 `find . -name '*.o'` 那类清单裁剪（它把模块也算进来了，必然打空）。
  单板用不到的两笔大头：`RC_CORE` 红外键映射表约 940KB（**不受
  `MEDIA_SUPPORT` 约束**，必须单独关）与 `KALLSYMS` 符号表约 1.8MB
  （需功能层先开 `EXPERT` 才关得动，代价是 oops 不再打印函数名）。
- **网口 PHY 驱动缺一**：`HISI_FEMAC`（MAC）与 `MDIO_HISI_FEMAC`（MDIO 总线）
  都在，但补丁库 rc3 版已移除 Festa PHY 驱动，`HISI_FESTA_PHY` 符号在内核树里
  不存在。若这台机的 EPHY 正是 Festa 系列，网口可能拿不到 link —— 网口是第二
  阶段的事，等驱动回到补丁库再补，流水线的「已移除符号报告」一节会盯住它。
- **内核内置命令行是强制的（`CONFIG_CMDLINE_FORCE=y`，2026-11-19 起）**：
  arm64 的 `arch/arm64/Kconfig` 里只有 `CMDLINE_FROM_BOOTLOADER` 与
  `CMDLINE_FORCE` 两选一，**没有** `CMDLINE_EXTEND`（那是 arm32 的东西），
  所以"保留引导器参数、再追加 earlycon"这条路在 arm64 上不存在。本版把
  `earlycon=pl011,mmio32,0xf8b00000,115200n8` 在内的整串参数放进
  `CONFIG_CMDLINE` 并强制启用，为的是让"串口看不见内核输出"不再发生。
  代价一条：**单刷 dtbo 分区换 rootfs 的玩法会失效**（`root=` 由内核定死）。
  进系统后想恢复该玩法，删掉功能层那两行（`CONFIG_CMDLINE=...` 与
  `CONFIG_CMDLINE_FORCE=y`）、以及裁剪层里对应的
  `# CONFIG_CMDLINE_FROM_BOOTLOADER is not set` 即可。
- **内存是 2GiB，别信 U-Boot 那句 1 GiB**：本机 U-Boot 打印
  `DRAM: 1 GiB` / `DDR Size: 1 GiB (Boot: 1 GiB)`，那是它自己的可映射上限，
  不是硬件容量。真机导出设备树的 `memory@0 = 0x80000000` 与真机
  `/proc/meminfo` 的 `MemTotal: 2018984 kB` 才作数（两者吻合）。
  这个值写错方向都会出事：写小了白白少认一半内存，写大了内核会遍历并不存在的
  物理页、在 console 建立之前挂住。流水线已对它做硬校验。
