#!/bin/bash
set -e
# GK6323V100C(Hi3798MV200H) 内核一键编译脚本
# 输出和hi3798mv100仓库完全一致：uImage格式boot.img(内置DTB) + 内核模块目录
# 基线: histb 7.4.rc2 / Linux 6.18.46 ARM64

# 配置参数
KERNEL_VERSION="6.18.46"
ARCH="arm64"
CROSS_COMPILE="aarch64-linux-gnu-"
LOAD_ADDR="0x2000000"
ENTRY_ADDR="0x2000000"
OUTPUT_DIR="$(pwd)/output"
THREADS=$(nproc)

echo "=========================================="
echo "GK6323V100C(Hi3798MV200H) 内核编译脚本"
echo "基线: Linux $KERNEL_VERSION histb 7.4.rc2"
echo "uImage参数: 无压缩 加载地址$LOAD_ADDR 入口点$ENTRY_ADDR DTB内置"
echo "=========================================="

# 检查依赖
check_deps() {
    echo "==> 检查编译依赖..."
    local deps="gcc-aarch64-linux-gnu make bison flex libssl-dev libelf-dev bc u-boot-tools"
    for dep in $deps; do
        if ! dpkg -l | grep -q "^ii  $dep"; then
            echo "安装依赖: $dep"
            sudo apt update
            sudo apt install -y gcc-aarch64-linux-gnu build-essential libncurses-dev bison flex libssl-dev libelf-dev bc u-boot-tools git
            break
        fi
    done
}

# 下载内核源码
get_kernel() {
    if [ ! -d "linux-$KERNEL_VERSION" ]; then
        echo "==> 下载Linux $KERNEL_VERSION 源码..."
        wget -c "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KERNEL_VERSION.tar.xz"
        tar xf "linux-$KERNEL_VERSION.tar.xz"
    fi

    # 应用histb 7.4.rc2补丁集
    if [ ! -f "linux-$KERNEL_VERSION/.histb_patched" ]; then
        echo "==> 应用海思平台补丁..."
        # 这里可以追加histb官方补丁，目前用主线内核已包含大部分Hi3798MV2X基础支持
        # 若后续需要补充板级驱动，将patch放入patches/目录即可自动应用
        if [ -d "patches" ]; then
            cd "linux-$KERNEL_VERSION"
            for patch in ../patches/*.patch; do
                patch -p1 < "$patch"
            done
            cd ..
        fi
        touch "linux-$KERNEL_VERSION/.histb_patched"
    fi
}

# 配置内核
config_kernel() {
    cd "linux-$KERNEL_VERSION"
    echo "==> 导入GK6323V100C默认配置..."
    cp ../configs/gk6323v100c_defconfig .config
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE olddefconfig
    cd ..
}

# 编译内核和模块
build_kernel() {
    cd "linux-$KERNEL_VERSION"
    echo "==> 编译内核（$THREADS线程）..."
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE -j$THREADS Image modules dtbs

    echo "==> 合并DTB到内核镜像（内置DTB）..."
    # 拼接DTB到Image末尾，实现单镜像启动
    cat arch/arm64/boot/Image arch/arm64/boot/dts/hisilicon/hi3798mv200h.dtb > arch/arm64/boot/Image-dtb

    echo "==> 生成uImage（boot.img，对齐原格式）..."
    mkimage -A arm64 -O linux -T kernel -C none \
        -a $LOAD_ADDR -e $ENTRY_ADDR \
        -n "GK6323V100C Linux $KERNEL_VERSION ARM64" \
        -d arch/arm64/boot/Image-dtb arch/arm64/boot/boot.img
    cd ..
}

# 安装模块
install_modules() {
    echo "==> 安装内核模块..."
    cd "linux-$KERNEL_VERSION"
    rm -rf "$OUTPUT_DIR/modules"
    mkdir -p "$OUTPUT_DIR/modules"
    make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE modules_install INSTALL_MOD_PATH="$OUTPUT_DIR/modules"
    cd ..
}

# 整理输出产物
package_output() {
    mkdir -p "$OUTPUT_DIR"
    echo "==> 整理输出产物..."
    cp "linux-$KERNEL_VERSION/arch/arm64/boot/boot.img" "$OUTPUT_DIR/boot.img"
    echo "boot.img大小: $(ls -lh $OUTPUT_DIR/boot.img | awk '{print $5}')"
    echo "模块目录: $OUTPUT_DIR/modules/lib/modules/$KERNEL_VERSION"
}

# 主流程
check_deps
get_kernel
config_kernel
build_kernel
install_modules
package_output

echo ""
echo "=========================================="
echo "编译完成！产物位置: $OUTPUT_DIR"
echo "  - boot.img: 内置DTB的uImage内核，直接写mmcblk0p15分区"
echo "  - modules/: 内核模块目录，解压覆盖到目标机/lib/modules/"
echo "=========================================="
echo "刷入方法见 README.md"
