#!/bin/bash
# 串口日志录制脚本，使用你指定的完整参数

TTY_DEV="/dev/ttyUSB0"
BAUD_RATE=1500000
LOG_NAME="uart_$(date +%Y%m%d_%H%M%S).log"

echo "====================串口日志工具===================="
echo "串口设备：$TTY_DEV"
echo "波特率：$BAUD_RATE"
echo "日志保存文件：$LOG_NAME"
echo "快捷键：Ctrl+A 松开再按 Q 正常退出"
echo "===================================================="
echo ""

picocom --baud "$BAUD_RATE" --databits 8 --parity n --flow n --imap lfcrlf --logfile "$LOG_NAME" "$TTY_DEV"

echo ""
echo "程序退出，日志文件：$LOG_NAME"
