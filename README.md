# GK6323V100C 主线内核：构建 + 刷写 + 实机验证

面向国科微 GK6323V100C 机顶盒（硅片等同海思 Hi3798MV200H / MV310，ARM64）的内核仓库：
在 GitHub Actions 上拉取源码、应用 histb 补丁，编译出可直接刷入的 `uImage` 与内核模块，
刷写方式与输出格式同 hi3798mv100 那套仓库。

**为什么有这个仓库**：作者那版 Debian 用的 BSP 内核（`6.18.46-gk6323-debian`）是纯内置内核
（`/proc/modules` 不存在），并且没有编入 USB 音频驱动，插上 USB 声卡能被枚举、却没有驱动接管，
出不了声。本仓库在 histb 主线上把 USB 音频打开，并把内核与模块一起产出。

---

## 一、仓库结构

```
.
├── .github/workflows/gk6323.yml   # 构建流水线：拉源码 → 打补丁 → 配置自检 → 编译 → 打包 → 发布 Release
├── gk6323v100c.config             # 单板配置叠加层（USB 音频就是在这里打开的）
├── apply_histb_patches.sh         # 补丁应用脚本（有 series 按 series，否则按文件名序号）
├── scripts/
│   ├── flash-boot.sh              # 目标机上刷写 boot 分区（可选写 dtbo）＋安装模块
│   └── verify-device.sh           # 目标机上一条命令自检
├── docs/
│   ├── build-and-flash.md         # 从构建到刷写的完整步骤
│   └── troubleshooting.md         # 踩过的坑与排查办法
└── .gitignore
```

三处触发路径固定为 `gk6323v100c.config`、`apply_histb_patches.sh`、`.github/workflows/gk6323.yml`，
改动其中任一文件即自动触发构建，也可以在 Actions 页面手动触发。

---

## 二、与 hi3798mv100 的差别只有 5 处

| 项目 | hi3798mv100 | 本仓库 |
| --- | --- | --- |
| 架构与工具链 | `ARCH=arm`，`arm-linux-gnueabihf-` | `ARCH=arm64`，`aarch64-linux-gnu-` |
| 内核镜像 | `zImage`，包成 `-A arm` 的 uImage | `Image`，包成 `-A arm64` 的 uImage |
| 设备树 | 追加在 `zImage` 末尾 | 追加在 `Image` 末尾，另单独发一份供 dtbo 分区用 |
| 单板配置 | `kernel.config` | `gk6323v100c.config`（叠加层），多一项 USB 音频 |
| 刷写分区 | `boot = /dev/mmcblk0p6` | `boot = /dev/mmcblk0p15`（60M），`dtbo = /dev/mmcblk0p10` |

其余（基线、补丁库、打包地址、产物形态、发布流程、刷写顺序）全部照搬。

一处写法上的差别值得留意：本仓库用**叠加层**而不是整份 `kernel.config`。好处是补丁新增的驱动符号
（要打完补丁才在 Kconfig 里可见）不会丢；代价是**被 `if` 包住的符号必须连父菜单一起写**，漏写时
子项会被 `olddefconfig` 静默丢弃，构建随后在「必须项」一节中止。这几对父符号见
`docs/troubleshooting.md` 构建阶段第 4 条。

---

## 三、快速开始

### 1. 构建

```bash
git init -b main
git add -A
git commit -m "GK6323V100C kernel build"
git remote add origin git@github.com:<你的账号>/<仓库名>.git
git push -u origin main
```

- **Settings → Actions → General → Workflow permissions** 选 **Read and write permissions**
  （发布 Release 需要写权限）。
- Actions → **GK6323V100C 内核自动构建** → **Run workflow**。
- 成功后产出 `boot.img`、`modules.tar.gz`、`Image`、设备树、`config-*`、`sha256sums.txt`，
  并自动创建 Release，标签形如 `gk6323v100c-7.4-rc2-b<N>`。

### 2. 刷入设备

```bash
# 把 Release 里的 boot.img 与 modules.tar.gz 传到盒子的 /tmp
sudo bash scripts/flash-boot.sh -i /tmp/boot.img -m /tmp/modules.tar.gz
sudo reboot
```

先解压模块、后写 boot 分区的顺序由脚本保证，不要手工颠倒。只想先看一遍动作加 `-n`。
脚本只碰 boot 分区，不碰 fastboot、bootargs、atf、trustedcore 这些底层分区。

### 3. 验证

```bash
sudo bash scripts/verify-device.sh
```

七组检查、末尾给出 `PASS / FAIL / SKIP` 汇总，全通过时退出码为 0。

---

## 四、关键约定

| 项目 | 取值 | 说明 |
| --- | --- | --- |
| 内核基线 | `7.4-rc2` / commit `fd9230005e85` | 与 mv100 仓库同一 pin，也与补丁库 `baseline` 一致 |
| 补丁库 | `histb-mainline_patches` | 严格应用，等价 `--fuzz=0`，冲突即回滚 |
| 设备树 | `hi3798mv200h-skyworth-stb.dtb` | 补丁库新增的创维代工 mv200h 板级 |
| uImage | 加载 / 入口 `0x02000000`，`-C none` | 设备树追加在 `Image` 末尾，校验魔数 `d00dfeed` |
| USB 音频 | `CONFIG_SND_USB_AUDIO=m` | 与 mv100 的 `kernel.config` 同形态，是模块 |
| 启动参数 | 内核内 `CONFIG_CMDLINE` 留空 | `root=` 与 `blkdevparts=` 由 bootargs 分区下发 |
| boot 分区 | `/dev/mmcblk0p15` | 起始 112M、长 60M，刷入 `boot.img` |
| dtbo 分区 | `/dev/mmcblk0p10` | 起始 50M、长 2M，需要时写入同一份 dtb |
| 根分区 | `/dev/mmcblk0p18` | ext4，由 bootargs 中的 `root=` 指定 |

升级内核版本时，只需把 `PATCHES_BASE_SHA` 与 `PATCHES_KERNEL_VERSION` 跟着补丁库
`baseline` 一起改，其余步骤照跑。换成自己的补丁库 fork，改 `PATCHES_REPO` 即可。

---

## 五、三件必须知道的事

1. **内核版本号会变**。本基线是 histb 主线，不是作者那版国科 BSP 内核，产出内核自报
   `7.4.x`，不再是 `6.18.46-gk6323-debian`；模块相应落在 `/lib/modules/7.4.x`。
   **内核与模块必须一起替换**，只换其中一个不会生效。
2. **内嵌的设备树能否生效取决于引导器**。设备树已按 mv100 的做法追加在内核镜像末尾，
   但 arm64 上是否需要额外从 dtbo 分区读取，各家引导器行为不同；所以 Release 里同时
   单独提供一份 dtb，必要时写入 `/dev/mmcblk0p10`。
3. **USB 音频驱动是模块**。这与 mv100 的 `kernel.config` 形态一致，所以刷完内核还必须
   解开 `modules.tar.gz`；`scripts/flash-boot.sh` 的顺序已经保证这一点。

---

## 六、文档索引

- [构建与刷写](docs/build-and-flash.md)
- [故障排查](docs/troubleshooting.md)
