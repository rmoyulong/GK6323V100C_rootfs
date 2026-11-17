# 构建与刷写：GK6323V100C

本文是从构建到上机的完整步骤。所有分区号都以这台实机读到的为准：
`boot = /dev/mmcblk0p15`（起始 112M、长 60M）、`dtbo = /dev/mmcblk0p10`（起始 50M、长 2M）、
`rootfs = /dev/mmcblk0p18`。

---

## 一、构建

1. 把这个目录初始化成 Git 仓库，推到你自己的 GitHub 上：

```bash
git init -b main
git add -A
git commit -m "GK6323V100C kernel build"
git remote add origin git@github.com:<你的账号>/<仓库名>.git
git push -u origin main
```

2. 打开写权限：**Settings → Actions → General → Workflow permissions** 选
   **Read and write permissions**。不开的话最后发布 Release 那一步会失败。
3. 触发：Actions → **GK6323V100C 内核自动构建** → **Run workflow**。

## 二、流水线做了什么

| 步骤 | 关键动作 | 失败会怎样 |
| --- | --- | --- |
| 拉源码 | 按 `PATCHES_BASE_SHA` 检出，并核对内核版本与补丁库 baseline 一致 | 版本不符直接中止 |
| 拉补丁库 | 检查 `baseline`，统计补丁数量 | 没有补丁即中止 |
| 打补丁 | 调 `apply_histb_patches.sh`，严格应用、冲突即回滚 | 不产出缺补丁的内核 |
| 查设备树 | 确认 `hi3798mv200h-skyworth-stb.dts` 在打完补丁后存在 | 没有该板级 dts 即中止 |
| 部署配置 | arm64 defconfig + 叠加层 + 强制关键项 + 逐行自检 | 必须项缺失即中止 |
| 编译 | `Image`、`dtbs`、`modules`，带 ccache | — |
| 打包 | dtb 追加到 Image 末尾，校验魔数 `d00dfeed`，再包 uImage | 魔数不对即中止 |
| 体积校验 | boot.img 必须小于 boot 分区 60M | 超限即中止 |
| 发布 | 上传产物并创建 Release | 无写权限时失败 |

## 三、产物

| 文件 | 用途 |
| --- | --- |
| `boot.img` | uImage 内核（内嵌设备树），写入 `/dev/mmcblk0p15` |
| `modules.tar.gz` | 内核模块，解压到根目录 `/` |
| `Image` | 未打包的裸内核，仅供核对 |
| `hi3798mv200h-skyworth-stb.dtb` | 设备树，需要时写入 `/dev/mmcblk0p10` |
| `config-7.4.0-rc2` | 本次实际使用的完整配置 |
| `sha256sums.txt` | 上述产物的校验值 |

## 四、上机刷写

先把两个文件传到盒子的 `/tmp`：

```bash
scp boot.img modules.tar.gz root@<盒子IP>:/tmp/
```

再在盒子上执行（脚本保证「先模块、后内核」的顺序，并自动备份 boot 分区）：

```bash
# 先看一遍将要做什么
sudo bash scripts/flash-boot.sh -n -i /tmp/boot.img -m /tmp/modules.tar.gz

# 确认无误后正式执行
sudo bash scripts/flash-boot.sh -i /tmp/boot.img -m /tmp/modules.tar.gz
sudo reboot
```

引导器如果不认内核内嵌的设备树，把同名 dtb 也写进 dtbo：

```bash
sudo bash scripts/flash-boot.sh -i /tmp/boot.img -m /tmp/modules.tar.gz \
     -d /tmp/hi3798mv200h-skyworth-stb.dtb
```

## 五、验证

```bash
sudo bash scripts/verify-device.sh
```

七组检查：内核版本、模块支持、设备树、分区表与根分区、USB 主控、USB 声卡、网络。
末尾给出 `PASS / FAIL / SKIP` 汇总，有 FAIL 时退出码非 0。插上 USB 声卡后，
第 6 组应当看到 `/proc/asound/cards` 里出现 USB 声卡、`lsusb -t` 的 Audio 接口
Driver 一栏变成 `snd-usb-audio`。

## 六、回滚

刷写脚本会把原 boot 分区整段备份到 `/root/boot-backup-<时间戳>.img`：

```bash
sudo dd if=/root/boot-backup-xxxxxxxx-xxxxxx.img of=/dev/mmcblk0p15 bs=1M conv=fsync && sync
sudo reboot
```

内核与新模块分别落在 boot 分区与 `/lib/modules/<release>`，两者互不影响：
回滚内核后旧的 `/lib/modules/7.4.0-rc2` 目录留着不碍事，也可以手工删掉。
