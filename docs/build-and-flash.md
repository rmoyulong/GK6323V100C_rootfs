# 构建与刷写

本文是 `README.md` 第四节到第七节的展开版，含逐步命令与流水线各步的把关点。

---

## 一、构建（GitHub Actions）

### 前置

- 仓库推到自己的 GitHub，Settings → Actions → General →
  Workflow permissions 选 **Read and write permissions**（发布 Release 需要）。
- 触发途径：Actions 页手动 Run workflow；或改动以下任一文件自动触发：
  - `.github/workflows/gk6323.yml`
  - `kernel.config`
  - `apply_histb_patches.sh`
  - `dts/gk6323v100c-chaoge-z71a.dts`、`dts/check-dts.py`

### 流水线各步与把关点

| 步骤 | 做什么 | 把关 |
| --- | --- | --- |
| 校验必要文件 | 确认 `apply_histb_patches.sh`、`kernel.config`、`dts/…dts` 都在 | 缺一个即中止 |
| 设备树静态校验 | `python3 dts/check-dts.py` | 漏分号、label 未定义、节点地址与 reg 不符 即中止 |
| 拉源码 | 按 `PATCHES_BASE_SHA` 提取工作树 | 版本号与补丁基线不一致即中止 |
| 应用补丁 | 严格应用（等价 `--fuzz=0`） | 冲突即回滚并中止 |
| 部署配置 | defconfig → 叠加 `kernel.config` → `scripts/config` 补项 → `olddefconfig` | 必须项缺一即中止 |
| 编译 | `make Image` + `make modules` | — |
| 编译自带设备树 | 用内核树自带 dtc 编译 `dts/…dts`；反编译回读 | 编译后的 dtb 缺 `cortex-a55`/`gic-v3`/`pl011`/`snps,dw-mshc`/`gk6323v100c` 即中止 |
| 追加并打包 | 把 dtb 追加到 `Image` 末尾，校验魔数 `d00dfeed`，`mkimage -A arm64 -T kernel -C none` | 魔数不对、或镜像超 60M 即中止 |
| 整理产物 | 收 `boot.img` / dtb / `modules.tar.gz` / `Image` / `config-*` / `sha256sums.txt` | — |
| 发布 | 建 Release 并附产物 | — |

### 必须项（少一项直接失败）

`ARCH_HISI`、`ARM_GIC_V3`、`ARM_ARCH_TIMER`、`SERIAL_AMBA_PL011_CONSOLE`、
`MMC_BLOCK`、`MMC_DW_PLTFM`、`EXT4_FS`、`PARTITION_ADVANCED`、
`CMDLINE_PARTITION`、`NET_VENDOR_HISILICON`、`PHYLIB`、`HISI_FEMAC`、
`USB_EHCI_HCD`、`PHY_HISI_INNO_USB2`、`MODULES`，以及本仓库存在的理由
`SND_USB_AUDIO`。

其中 `CMDLINE_PARTITION` 必须排在父菜单 `PARTITION_ADVANCED` 之后——
本机 `root=` 与全部 18 个分区都由 `bootargs` 里的 `blkdevparts=` 下发，
少了它内核看不到 `mmcblk0p18`，直接起不来。

---

## 二、刷写（目标机）

把 Release 里的三个文件传到机器 `/tmp`，然后：

```bash
# 1. 备份原 boot 分区
sudo dd if=/dev/mmcblk0p15 of=/root/boot.bak bs=1M conv=fsync

# 2. 先装模块（内核与模块必须同版本）
cd / && sudo tar -xzf /tmp/modules.tar.gz && sync
sudo depmod -a "$(ls /lib/modules | sort -V | tail -1)"

# 3. 刷内核
sudo dd if=/tmp/boot.img of=/dev/mmcblk0p15 bs=1M conv=fsync && sync

# 4. 刷设备树 —— 本机型必须这一步
sudo dd if=/tmp/gk6323v100c-chaoge-z71a.dtb of=/dev/mmcblk0p10 bs=1K conv=fsync && sync

# 5. 重启
sudo reboot
```

或用脚本（含备份、大小校验、dry-run）：

```bash
sudo bash scripts/flash-boot.sh -i boot.img -m modules.tar.gz \
     -d gk6323v100c-chaoge-z71a.dtb -n
sudo bash scripts/flash-boot.sh -i boot.img -m modules.tar.gz \
     -d gk6323v100c-chaoge-z71a.dtb
```

### 三个容易搞错的地方

- **顺序不能颠倒**：先模块后内核。反了会出现"内核已换、模块还是旧的"，
  USB 音频模块不在 `/lib/modules/7.4.x` 下。
- **dtb 必须写 dtbo 分区（p10）**：真机运行时用的就是这个分区的设备树。
  作者原 `boot.img` 内没有内嵌 dtb，所以内嵌的那份不生效。
- **分区节点不要写错**：`boot = /dev/mmcblk0p15`（起始 112M、长 60M）、
  `dtbo = /dev/mmcblk0p10`（起始 50M、长 2M）。刷前可先
  `for p in /sys/block/mmcblk0/mmcblk0p*; do echo $(basename $p) start=$(cat $p/start) size=$(cat $p/size); done`
  对照一遍。

---

## 三、验证

TTL 串口 **115200**，看日志停在哪一步：

| 现象 | 说明 |
| --- | --- |
| 一个字都没有 | DTB 或 GIC 初始化卡住 —— 先确认 dtbo 分区写的是新 dtb |
| 出 `Booting Linux` + earlycon 后停住 | 时钟或 eMMC 未就绪 |
| 打印出 mmcblk0 分区表 | eMMC 通了，看根文件系统能否挂载 |
| 进到 shell | 第一阶段完成 |

起来后：

```bash
sudo bash scripts/verify-device.sh
```

重点看三项：设备树 model 是否为 `GK6323V100C / Z71A`、`lsmod | grep snd_usb_audio`
是否加载、`cat /proc/asound/cards` 是否多出 USB 卡。

---

## 四、回滚

```bash
sudo dd if=/root/boot.bak of=/dev/mmcblk0p15 bs=1M conv=fsync && sync && reboot
```

本次同时改写了 dtbo 分区，回滚内核不会恢复原设备树；有原机 `dtbo.img` 就
一并写回 `/dev/mmcblk0p10`。手上有救砖包时，走 HiTool 只勾 `boot.img` 与
`dtbo.img` 两个分区刷回即可。
