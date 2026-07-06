#!/bin/bash
#
# serial-mon.sh - 快捷串口监控脚本
#
# 用法:
#   ./scripts/serial-mon.sh                    # 默认 /dev/ttyUSB0, 1500000
#   ./scripts/serial-mon.sh /dev/ttyUSB1       # 指定串口
#   ./scripts/serial-mon.sh /dev/ttyUSB0 115200 # 指定串口和波特率
#

SERIAL_DEV="${1:-/dev/ttyUSB0}"
SERIAL_BAUD="${2:-1500000}"

# 检查串口
if [ ! -e "${SERIAL_DEV}" ]; then
    echo "[ERROR] 串口设备不存在: ${SERIAL_DEV}"
    echo "  可用设备："
    ls -l /dev/ttyUSB* /dev/ttyACM* /dev/ttyCH341* 2>/dev/null || echo "  (无)"
    echo ""
    echo "用法: $0 [串口设备] [波特率]"
    echo "示例: $0 /dev/ttyUSB1 115200"
    exit 1
fi

echo "═══════════════════════════════════════════"
echo "  RK3506 串口监控"
echo "  设备: ${SERIAL_DEV}"
echo "  波特率: ${SERIAL_BAUD}"
echo "  退出: Ctrl+A, Ctrl+X (picocom)"
echo "         Ctrl+T, q    (tio)"
echo "         Ctrl+A, :quit (screen)"
echo "═══════════════════════════════════════════"

# 自动选择工具
if command -v tio &>/dev/null; then
    # tio - 最佳体验
    mkdir -p logs
    logfile="logs/boot-$(date +%Y%m%d-%H%M%S).log"
    echo "日志保存: ${logfile}"
    tio -b "${SERIAL_BAUD}" --log "${logfile}" "${SERIAL_DEV}"
elif command -v picocom &>/dev/null; then
    exec picocom -b "${SERIAL_BAUD}" -d 8 -p n -f n "${SERIAL_DEV}"
elif command -v screen &>/dev/null; then
    exec screen "${SERIAL_DEV}" "${SERIAL_BAUD}"
elif command -v minicom &>/dev/null; then
    exec minicom -D "${SERIAL_DEV}" -b "${SERIAL_BAUD}"
else
    echo "[ERROR] 未找到串口工具！请安装: sudo apt install picocom"
    exit 1
fi
