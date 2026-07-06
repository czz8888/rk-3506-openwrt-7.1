#!/bin/bash
# HZ-RK3506SP MiniEVM 自动刷机测试脚本
# 用法: bash flash_and_test.sh

set -e

# Resolve workspace path from script location instead of quoted '~'.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OPENWRT_DIR="${OPENWRT_DIR:-${SCRIPT_DIR}}"

LOADER="${OPENWRT_DIR}/rk3506_spl_loader_v1.04.110.bin"
EMMC_IMG="${OPENWRT_DIR}/bin/targets/rockchip/rk3506/openwrt-rockchip-rk3506-hzhy_mini_evm_emmc-squashfs-emmc.img"

# Fallback: pick a matching RK3506 SPL loader in repo root when version changes.
if [ ! -f "${LOADER}" ]; then
    LOADER_CANDIDATE="$(find "${OPENWRT_DIR}" -maxdepth 1 -type f -name 'rk3506_spl_loader_v*.bin' | sort | tail -n 1)"
    if [ -n "${LOADER_CANDIDATE}" ]; then
        LOADER="${LOADER_CANDIDATE}"
    fi
fi

echo "============================================"
echo " HZ-RK3506SP MiniEVM 刷机脚本"
echo "============================================"
echo ""
echo "镜像: ${EMMC_IMG}"
echo "Loader: ${LOADER}"
echo ""

# Step 1: Check files
if [ ! -f "${LOADER}" ]; then
    echo "❌ Loader 不存在: ${LOADER}"
    exit 1
fi
if [ ! -f "${EMMC_IMG}" ]; then
    echo "❌ 镜像不存在: ${EMMC_IMG}"
    exit 1
fi
echo "✅ 文件检查通过"
echo ""

# Step 2: Wait for Maskrom
echo "⏳ 等待设备进入 Maskrom 模式..."
echo "   操作: 按住 RECOVERY 键 → USB 上电 → 松开 RECOVERY"
echo ""
for i in $(seq 1 30); do
    DEV_COUNT=$(sudo upgrade_tool LD 2>/dev/null | grep -c "DevNo" || true)
    if [ "${DEV_COUNT}" -gt 0 ]; then
        echo "✅ 检测到设备 (Maskrom 模式)"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ 超时: 未检测到设备，请检查 USB 连接和 RECOVERY 按键"
        exit 1
    fi
    sleep 2
    echo -n "."
done
echo ""

# Step 3: Download loader
echo "📥 下载 Loader..."
sudo upgrade_tool DB "${LOADER}"
echo "✅ Loader 下载完成"

# Step 4: Write image
echo "📀 写入 eMMC 镜像 (176MB，约需 30 秒)..."
sudo upgrade_tool WL 0 "${EMMC_IMG}"
echo "✅ 镜像写入完成"

# Step 5: Reset
echo "🔄 复位设备..."
sudo upgrade_tool RD
echo "✅ 复位完成"

echo ""
echo "============================================"
echo " 刷机完成！"
echo "============================================"
echo ""
echo "下一步:"
echo " 1. 拔掉 USB 线"
echo " 2. 接 DC 12V 电源"
echo " 3. 连接串口 (115200 8N1)"
echo " 4. 观察启动日志"
echo ""
echo "串口连接命令:"
echo "  sudo picocom -b 115200 /dev/ttyUSB0"
echo "  或"
echo "  sudo minicom -D /dev/ttyUSB0"
echo ""
