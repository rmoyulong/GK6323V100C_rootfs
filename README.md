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
| 内核镜像 | `zImage` → `-A arm` uImage | `Image` → `-A arm64` uImage |
| 设备树 | 类同做法，追加到镜像末尾 | 追加到 `Image` 末尾，另单独发一份 |
| 单板配置 | `kernel.config`（整份） | `gk6323v100c.config`（叠加层） |
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
3. 也可以在改动 `gk6323v100c.config`、`apply_histb_patches.sh`、`dts/*.dts`
   或本workflow时自动触发。

流水线里会做这些把关：设备树静态校验（漏分号 / label 未定义 / 节点地址与
reg 不符）→ **从补丁库 baseline 自动读取内核版本与基线 commit** → 内核版本与
补丁基线核对 → 配置必须项硬校验 → 设备树追加处魔数必须是 `d00dfeed` →
编译后的 dtb 反编译回读，确认含 `cortex-a55`、`gic-v3`、`pl011`、
`snps,dw-mshc`、`gk6323v100c` → 镜像不得超 60M。

补丁库更新后**不必再改 workflow**：`KERNEL_VERSION` 与 `BASE_SHA` 以补丁库的
`baseline` 文件为准（`=` 与 `:=` 两种写法都认），workflow 里写的那两个值只是
补丁库缺该文件时的兜底。

配置自检分四节，含义不同，别混看：

| 小节 | 判什么 | 没通过意味着什么 |
| --- | --- | --- |
| 必须项 | 少一项这台机器就起不来或目标落空 | **直接中止构建** |
| 期望项 | 功能相关符号是否生效 | 只告警；会自动打印该符号的 Kconfig 定义，并区分「只是被关掉」与「内核树里没这个符号」 |
| 已移除符号报告 | 补丁库已不再提供的符号（如 `HISI_FESTA_PHY`）在树里是否存在 | 仅报告，不中止 |
| 派生符号报告 | 无 prompt 符号（`SND_PCM`、`SND_TIMER`、`ARM_GIC_V3_ITS` 等）的实际取值 | 仅报告。这类符号写进叠加层也改不动，所以叠加层里根本不写 |

两个已经踩过、已经修掉的坑：

- 自检取值统一走 `lookup()`。此前写成 `CUR="$(grep … | head -1)"`，一旦某符号在
  `.config` 里一行都没有，`set -euo pipefail` 会让整个步骤**静默退出**，日志只剩
  `exit code 1`，既没有告警也没有诊断。
- 补丁库 `baseline` 是 make 写法（`KERNEL_VERSION := 7.4-rc3`）。只认 `=` 的正则会
  取到空串、静默回落到兜底值，「自动读基线」形同失效；现在两种写法都认。

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

---

## 六、验证

接 TTL 串口（**115200**）看启动日志，按停在哪一步定位：

| 现象 | 说明 | 下一步 |
| --- | --- | --- |
| 一个字都没有 | DTB 或 GIC 初始化卡住 | 确认 dtbo 分区写的是新 dtb |
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

- **eMMC 依赖 bootloader 已配好的时钟**：国科私有 CRU 没有主线驱动，本版
  把外设时钟改指 fixed-clock 并保持 `clk_ignore_unused`，能否起来取决于
  引导器是否已把 SD/eMMC 时钟打开。这是第一版的最大不确定点。
- **板载 ES8316 音频暂不可用**：它走国科 AIAO 控制器，主线无驱动；本版
  设备树未包含该节点（保留给后续版本）。USB 声卡不受影响。
- **内核版本号是 7.4.x**，不是作者那版 `6.18.46-gk6323-debian`，模块装在
  `/lib/modules/7.4.x`，内核与模块必须一起替换。
- CPU 变频（`goke,gk6323-cpufreq`）、红外、温度传感器同样缺少主线驱动，
  本版未启用。
- **网口 PHY 驱动缺一**：`HISI_FEMAC`（MAC）与 `MDIO_HISI_FEMAC`（MDIO 总线）
  都在，但补丁库 rc3 版已移除 Festa PHY 驱动，`HISI_FESTA_PHY` 符号在内核树里
  不存在。若这台机的 EPHY 正是 Festa 系列，网口可能拿不到 link —— 网口是第二
  阶段的事，等驱动回到补丁库再补，流水线的「已移除符号报告」一节会盯住它。
