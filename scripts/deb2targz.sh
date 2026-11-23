#!/bin/bash

# 检查参数
if [ $# -ne 1 ]; then
    echo "用法: $0 <内核deb包>"
    echo "示例: $0 linux-image-6.12.28-current-meson64"
    exit 1
fi

DEB_FILE="$1"
DEB_DIR=$(dirname "$(realpath "$DEB_FILE")")
TEMP_DIR="$DEB_DIR/temp_$(date +%s%N)"
EXTRACT_DIR="$TEMP_DIR/extract"
TAR_DIR="$TEMP_DIR/tar"

# 检查文件是否存在
if [ ! -f "$DEB_FILE" ]; then
    echo "错误: 文件 $DEB_FILE 不存在"
    exit 1
fi

# 检查文件格式
if ! file "$DEB_FILE" | grep -q "Debian binary package"; then
    echo "错误: $DEB_FILE 不是有效的 deb 包"
    exit 1
fi

# 创建临时目录
mkdir -p "$TEMP_DIR"
if [ $? -ne 0 ]; then
    echo "错误: 无法创建临时目录 $TEMP_DIR"
    exit 1
fi

echo "临时目录: $TEMP_DIR"
echo "正在解压 deb 包..."

# 解压deb包
dpkg -x "$DEB_FILE" "$EXTRACT_DIR"

if [ $? -ne 0 ]; then
    echo "错误: 解压 deb 包失败"
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "正在创建 tar.gz 包..."
# 获取内核版本信息
##KERNEL_VERSION=$(dpkg -I "$DEB_FILE" | grep -oP "Package: \Klinux-image-[^\s]+" | sed 's/linux-image-//')
KERNEL_VERSION=""
if [ -z "$KERNEL_VERSION" ]; then
    KERNEL_VERSION=$(basename "$DEB_FILE" | sed 's/linux-image-//' | sed 's/_.*//' | sed 's/\.deb$//')
fi

TAR_FILE="$DEB_DIR/${KERNEL_VERSION}.tar.gz"

# 创建目标目录结构
mkdir -p "$TAR_DIR/boot"
mkdir -p "$TAR_DIR/boot/dtbs"
mkdir -p "$TAR_DIR/usr/lib"

# 移动内核文件到 boot 目录
mv "$EXTRACT_DIR"/boot/vmlinuz-* "$TAR_DIR/boot/" 2>/dev/null || true
mv "$EXTRACT_DIR"/boot/initrd.img-* "$TAR_DIR/boot/" 2>/dev/null || true
mv "$EXTRACT_DIR"/boot/System.map-* "$TAR_DIR/boot/" 2>/dev/null || true
mv "$EXTRACT_DIR"/boot/config-* "$TAR_DIR/boot/" 2>/dev/null || true

# 移动 dtb 文件到 boot/dtbs 目录
if [ -d "$EXTRACT_DIR/usr/lib/linux-image-$KERNEL_VERSION" ]; then
    # Ubuntu/Debian 风格的 dtb 文件位置
    mkdir -p "$TAR_DIR/boot/dtbs"
    mv "$EXTRACT_DIR/usr/lib/linux-image-$KERNEL_VERSION/"* "$TAR_DIR/boot/dtbs/" 2>/dev/null || true
    # 删除空目录
    rmdir "$EXTRACT_DIR/usr/lib/linux-image-$KERNEL_VERSION" 2>/dev/null || true
elif [ -d "$EXTRACT_DIR/boot/dtb" ]; then
    # 其他可能的 dtb 文件位置
    mkdir -p "$TAR_DIR/boot/dtbs"
    mv "$EXTRACT_DIR/boot/dtb/"* "$TAR_DIR/boot/dtbs/" 2>/dev/null || true
    rmdir "$EXTRACT_DIR/boot/dtb" 2>/dev/null || true
elif [ -d "$EXTRACT_DIR/boot/dtbs" ]; then
    mv "$EXTRACT_DIR/boot/dtbs/"* "$TAR_DIR/boot/dtbs/" 2>/dev/null || true
    rmdir "$EXTRACT_DIR/boot/dtbs" 2>/dev/null || true
fi

# 移动 modules 到 usr/lib 目录
if [ -d "$EXTRACT_DIR/lib/modules" ]; then
    mv "$EXTRACT_DIR/lib/modules" "$TAR_DIR/usr/lib/" 2>/dev/null || true
fi

# 清理可能残留的空目录
rmdir "$EXTRACT_DIR/boot" 2>/dev/null || true
rmdir "$EXTRACT_DIR/usr/lib" 2>/dev/null || true
rmdir "$EXTRACT_DIR/usr" 2>/dev/null || true
rmdir "$EXTRACT_DIR/lib" 2>/dev/null || true

# 创建tar.gz包
cd "$TAR_DIR" && tar -czf "$TAR_FILE" .
if [ $? -eq 0 ]; then
    echo "转换成功!"
    echo "生成的 tar.gz 包: $TAR_FILE"
    echo "目录结构:"
    echo "  /boot/vmlinuz-*"
    echo "  /boot/initrd.img-*"
    echo "  /boot/System.map-*"
    echo "  /boot/config-*"
    echo "  /boot/dtbs/ - 设备树文件"
    echo "  /usr/lib/modules/ - 内核模块"
    echo ""
    echo "包含的文件:"
    tar -tzf "$TAR_FILE" | head -15
    if [ $(tar -tzf "$TAR_FILE" | wc -l) -gt 15 ]; then
        echo "... 和其他文件"
    fi
else
    echo "错误: 创建 tar.gz 包失败"
fi

# 清理临时文件
echo "清理临时文件..."
rm -rf "$TEMP_DIR"

echo "完成!"