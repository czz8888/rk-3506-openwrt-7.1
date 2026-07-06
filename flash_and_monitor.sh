#!/bin/bash
# HZ-RK3506SP MiniEVM 刷机 + 串口监听脚本
# 注意: 请将 YOUR_SUDO_PASSWORD 替换为实际的 sudo 密码

set -e
PASS="YOUR_SUDO_PASSWORD"
OPENWRT_DIR="~/rk-3506-openwrt-7.1"
LOADER="${OPENWRT_DIR}/rk3506_spl_loader_v1.04.110.bin"
EMMC_IMG="${OPENWRT_DIR}/bin/targets/rockchip/rk3506/openwrt-rockchip-rk3506-hzhy_mini_evm_emmc-squashfs-emmc.img"
SERIAL="/dev/ttyUSB0"
BAUD="1500000"
LOG_FILE="${OPENWRT_DIR}/serial_boot_$(date +%Y%m%d_%H%M%S).log"

echo "============================================"
echo " HZ-RK3506SP MiniEVM 刷机 + 串口监听"
echo "============================================"
echo "串口: ${SERIAL} @ ${BAUD}"
echo "日志: ${LOG_FILE}"
echo ""

# Step 1: Start serial logger in background
echo "📡 启动串口监听 (${BAUD} baud)..."
picocom -b ${BAUD} ${SERIAL} --noreset --quiet 2>/dev/null | tee "${LOG_FILE}" &
PICO_PID=$!
sleep 1
echo "   串口监听 PID: ${PICO_PID}"

# Cleanup on exit
cleanup() {
    echo ""
    echo "🛑 停止串口监听..."
    kill ${PICO_PID} 2>/dev/null || true
    echo "📝 日志已保存到: ${LOG_FILE}"
}
trap cleanup EXIT

# Step 2: Wait for Maskrom
echo ""
echo "⏳ 等待设备进入 Maskrom 模式..."
echo "   👉 请操作: 按住 RECOVERY → USB 上电 → 松开 RECOVERY"
for i in $(seq 1 60); do
    DEV_COUNT=$(echo "${PASS}" | sudo -S upgrade_tool LD 2>/dev/null | grep -c "DevNo" || true)
    if [ "${DEV_COUNT}" -gt 0 ]; then
        echo ""
        echo "✅ 检测到 Maskrom 设备！"
        break
    fi
    if [ $i -eq 60 ]; then
        echo ""
        echo "❌ 超时: 60秒内未检测到设备"
        exit 1
    fi
    sleep 1
    echo -n "."
done

# Step 3: Flash loader
echo ""
echo "📥 下载 Loader..."
echo "${PASS}" | sudo -S upgrade_tool DB "${LOADER}" 2>&1
echo "✅ Loader 下载完成"

# Step 4: Write eMMC image
echo "📀 写入 eMMC 镜像 (176MB)..."
echo "${PASS}" | sudo -S upgrade_tool WL 0 "${EMMC_IMG}" 2>&1
echo "✅ 镜像写入完成"

# Step 5: Reset - this will trigger boot
echo "🔄 复位设备（观察串口启动日志）..."
echo ""
echo "===================== 串口日志 ====================="
echo "${PASS}" | sudo -S upgrade_tool RD 2>&1

# Wait and capture serial output
echo ""
echo "⏳ 等待设备启动 (30秒)..."
sleep 30

echo ""
echo "============================================"
echo " 日志已保存到: ${LOG_FILE}"
echo " 查看日志: cat ${LOG_FILE}"
echo "============================================"
