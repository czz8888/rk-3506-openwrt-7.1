#!/bin/bash
#
# flash-test.sh - RK3506 OpenWrt 固件刷机与启动测试脚本
#
# 功能：
#   1. 自动刷写 eMMC 固件（通过 upgrade_tool）
#   2. 监听串口输出，验证系统启动
#   3. 保存启动日志
#
# 使用：
#   ./scripts/flash-test.sh                         # 刷写 squashfs 镜像
#   ./scripts/flash-test.sh -f ext4                  # 刷写 ext4 镜像
#   ./scripts/flash-test.sh -m monitor-only          # 仅串口监控
#   ./scripts/flash-test.sh -h                       # 查看帮助
#

set -euo pipefail

# ============================================================
# 配置参数（可按需修改）
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FW_DIR="${SCRIPT_DIR}/bin/targets/rockchip/rk3506"
LOADER_DIR="${SCRIPT_DIR}"
LOADER_DIR2="${SCRIPT_DIR}/staging_dir/target-arm_cortex-a7+vfpv4_musl_eabi/image"

# 默认使用 squashfs 镜像
IMAGE_NAME="openwrt-rockchip-rk3506-hzhy_mini_evm_emmc-squashfs-emmc.img"
# upgrade_tool DB 需要 Download Loader 格式（文件头 "LDR "），
# 而非 rksd 格式（文件头 "RKCP"）的 idbloader.img。
# rk3506_spl_loader_v1.04.110.bin 是预制的 USB 下载 loader。
LOADER_NAME="rk3506_spl_loader_v1.04.110.bin"

# 串口配置
SERIAL_DEV="${SERIAL_DEV:-/dev/ttyUSB0}"
SERIAL_BAUD="${SERIAL_BAUD:-1500000}"
LOG_DIR="${SCRIPT_DIR}/logs"

# upgrade_tool 路径
UPGRADE_TOOL="${UPGRADE_TOOL:-upgrade_tool}"

# ============================================================
# 颜色输出
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }
header()  { echo -e "\n${CYAN}══════════════════════════════════════════════${NC}"; echo -e "${CYAN}  $*${NC}"; echo -e "${CYAN}══════════════════════════════════════════════${NC}\n"; }

# ============================================================
# 帮助
# ============================================================
usage() {
    cat <<EOF
RK3506 OpenWrt 刷机与启动测试脚本

用法: $0 [选项]

选项:
  -f <ext4|squashfs>   选择固件类型（默认: squashfs）
  -m monitor-only      仅启动串口监控，不刷机
  -p <串口设备>         指定串口设备（默认: /dev/ttyUSB0）
  -b <波特率>           指定串口波特率（默认: 1500000）
  -l <loader路径>       指定 loader 文件路径
  -i <镜像路径>         指定固件镜像路径
  -s                   跳过刷机，仅验证镜像文件
  -h                   显示帮助信息

示例:
  $0                           # 刷写 squashfs 镜像并监控启动
  $0 -f ext4                   # 刷写 ext4 镜像并监控启动
  $0 -m monitor-only           # 仅串口监控
  $0 -p /dev/ttyUSB1 -b 115200 # 指定不同串口和波特率

EOF
    exit 0
}

# ============================================================
# 参数解析
# ============================================================
FW_TYPE="squashfs"
ACTION="flash-and-monitor"
SKIP_FLASH=0

while getopts "f:mp:b:l:i:sh" opt; do
    case $opt in
        f) FW_TYPE="$OPTARG" ;;
        m) ACTION="monitor-only" ;;
        p) SERIAL_DEV="$OPTARG" ;;
        b) SERIAL_BAUD="$OPTARG" ;;
        l) LOADER_OVERRIDE="$OPTARG" ;;
        i) IMAGE_OVERRIDE="$OPTARG" ;;
        s) SKIP_FLASH=1 ;;
        h) usage ;;
        *) usage ;;
    esac
done

# ============================================================
# 前置检查
# ============================================================
check_prerequisites() {
    header "检查运行环境"

    # 检查 upgrade_tool
    if ! command -v "${UPGRADE_TOOL}" &>/dev/null; then
        error "未找到 upgrade_tool！请先安装。"
        echo "  安装方法："
        echo "    wget https://github.com/rockchip-linux/rkdeveloptool/releases/... "
        echo "    或从 Rockchip 官方获取 upgrade_tool"
        exit 1
    fi
    info "upgrade_tool: $(command -v "${UPGRADE_TOOL}")"

    # 检查串口工具
    local serial_tool=""
    for tool in picocom screen tio minicom; do
        if command -v "$tool" &>/dev/null; then
            serial_tool="$tool"
            break
        fi
    done
    if [ -z "$serial_tool" ]; then
        warn "未找到串口终端工具，建议安装："
        echo "    sudo apt install picocom   # 推荐"
        echo "    sudo apt install screen"
        echo "    sudo apt install tio"
    else
        info "串口工具: ${serial_tool}"
    fi

    # 检查必要文件
    if [ "${ACTION}" != "monitor-only" ]; then
        local loader=""
        if [ -n "${LOADER_OVERRIDE:-}" ]; then
            loader="${LOADER_OVERRIDE}"
        elif [ -f "${LOADER_DIR}/${LOADER_NAME}" ]; then
            loader="${LOADER_DIR}/${LOADER_NAME}"
        elif [ -f "${LOADER_DIR2}/${LOADER_NAME}" ]; then
            loader="${LOADER_DIR2}/${LOADER_NAME}"
        else
            error "loader 文件不存在！"
            echo "  查找位置:"
            echo "    ${LOADER_DIR}/${LOADER_NAME}"
            echo "    ${LOADER_DIR2}/${LOADER_NAME}"
            echo "  请确认文件 ${LOADER_NAME} 存在于项目根目录。"
            exit 1
        fi
        info "Loader: ${loader} ($(du -h "$loader" | cut -f1))"

        local image=""
        if [ -n "${IMAGE_OVERRIDE:-}" ]; then
            image="${IMAGE_OVERRIDE}"
        else
            image="${FW_DIR}/openwrt-rockchip-rk3506-hzhy_mini_evm_emmc-${FW_TYPE}-emmc.img"
        fi

        if [ ! -f "$image" ]; then
            # 尝试 .img.gz
            if [ -f "${image}.gz" ]; then
                info "发现压缩镜像: ${image}.gz，解压中..."
                gunzip -kf "${image}.gz"
            else
                error "镜像文件不存在: ${image}"
                echo "  可用镜像："
                ls -1 "${FW_DIR}"/*.img* 2>/dev/null || echo "  (无)"
                exit 1
            fi
        fi
        info "固件镜像: ${image} ($(du -h "$image" | cut -f1))"
    fi
}

# ============================================================
# 刷写固件
# ============================================================
flash_firmware() {
    header "刷写固件到 eMMC"

    local loader=""
    if [ -n "${LOADER_OVERRIDE:-}" ]; then
        loader="${LOADER_OVERRIDE}"
    elif [ -f "${LOADER_DIR}/${LOADER_NAME}" ]; then
        loader="${LOADER_DIR}/${LOADER_NAME}"
    elif [ -f "${LOADER_DIR2}/${LOADER_NAME}" ]; then
        loader="${LOADER_DIR2}/${LOADER_NAME}"
    else
        error "loader 文件不存在！"
        exit 1
    fi
    local image=""
    if [ -n "${IMAGE_OVERRIDE:-}" ]; then
        image="${IMAGE_OVERRIDE}"
    else
        image="${FW_DIR}/openwrt-rockchip-rk3506-hzhy_mini_evm_emmc-${FW_TYPE}-emmc.img"
    fi

    # 检查是否为 raw image（非 MBR/GPT 说明不对）
    if ! file "$image" | grep -qE "DOS/MBR boot sector|GPT"; then
        warn "镜像可能不是原始 eMMC 镜像，请确认："
        file "$image"
    fi

    # 步骤 1: 列出设备
    info "查看当前连接的设备..."
    ${UPGRADE_TOOL} LD || true

    # 步骤 2: 下载 Loader
    echo ""
    info "步骤 1/3: 下载 Loader 到设备..."
    info "注意: 需要 sudo 权限访问 USB 设备"
    if ! sudo ${UPGRADE_TOOL} DB "${loader}"; then
        error "下载 Loader 失败！"
        echo "  可能原因："
        echo "    1. 设备未进入 Maskrom/Loader 模式"
        echo "    2. USB 连接不稳定"
        echo "    3. 当前用户无权限（尝试 sudo）"
        echo ""
        echo "  请确认："
        echo "    - 按住 RECOVERY 按钮"
        echo "    - 连接 USB"
        echo "    - 上电"
        echo "    - 3 秒后松开 RECOVERY"
        echo "    - 运行 '${UPGRADE_TOOL} LD' 查看设备"
        exit 1
    fi
    info "Loader 下载成功！"

    # 步骤 3: 写入完整镜像
    echo ""
    info "步骤 2/3: 写入 eMMC 镜像（这可能需要几分钟）..."
    info "镜像大小: $(du -h "$image" | cut -f1)"
    info "开始写入..."

    if ! sudo ${UPGRADE_TOOL} WL 0 "${image}"; then
        error "写入镜像失败！"
        exit 1
    fi
    info "镜像写入成功！"

    # 步骤 4: 复位设备
    echo ""
    info "步骤 3/3: 复位设备..."
    if ! sudo ${UPGRADE_TOOL} RD; then
        warn "复位命令发送失败，请手动复位开发板。"
    else
        info "设备已复位，请拔掉 USB 线，使用 DC 电源启动。"
    fi

    echo ""
    info "刷机完成！"
}

# ============================================================
# 串口启动监控
# ============================================================
monitor_serial() {
    header "串口启动监控"
    info "设备:   ${SERIAL_DEV}"
    info "波特率: ${SERIAL_BAUD}"
    info "日志:   ${LOG_DIR}/boot-$(date +%Y%m%d-%H%M%S).log"
    echo ""

    # 检查串口是否存在
    if [ ! -e "${SERIAL_DEV}" ]; then
        error "串口设备不存在: ${SERIAL_DEV}"
        echo "  请确认："
        echo "    - USB 转串口模块已连接"
        echo "    - 使用 'ls -l /dev/ttyUSB*' 查看设备"
        echo "    - 当前用户是否在 dialout 组？运行: sudo usermod -aG dialout \$USER"
        exit 1
    fi

    # 检查串口是否被占用
    if command -v lsof &>/dev/null; then
        if lsof "${SERIAL_DEV}" &>/dev/null; then
            error "串口 ${SERIAL_DEV} 已被其他进程占用！"
            lsof "${SERIAL_DEV}"
            exit 1
        fi
    fi

    mkdir -p "${LOG_DIR}"
    local logfile="${LOG_DIR}/boot-$(date +%Y%m%d-%H%M%S).log"

    info "等待开发板启动...（开发板上电后即可看到日志）"
    info "按 Ctrl+C 停止监控"
    echo ""

    # 选择可用的串口工具
    if command -v tio &>/dev/null; then
        # tio: 支持日志记录，体验好
        tio -b "${SERIAL_BAUD}" --log "${logfile}" "${SERIAL_DEV}"
    elif command -v picocom &>/dev/null; then
        # picocom: 经典工具，通过 tee 记录日志
        picocom -b "${SERIAL_BAUD}" -d 8 -p n -f n "${SERIAL_DEV}" \
            2>&1 | tee "${logfile}"
        # 注: picocom 退出时会结束 tee，日志仍会保存
    elif command -v screen &>/dev/null; then
        # screen: 内置日志功能
        info "启动 screen，日志将保存到 ${logfile}"
        screen -L -Logfile "${logfile}" "${SERIAL_DEV}" "${SERIAL_BAUD}"
    elif command -v minicom &>/dev/null; then
        # minicom: 配置捕获日志
        info "启动 minicom，请按 Ctrl+A -> L 开启日志捕获"
        minicom -D "${SERIAL_DEV}" -b "${SERIAL_BAUD}"
    else
        # 使用 stty + cat 最小化方案
        info "使用 stty + cat 原始模式..."
        stty -F "${SERIAL_DEV}" "${SERIAL_BAUD}" cs8 -cstopb -parenb
        cat "${SERIAL_DEV}" | tee "${logfile}"
    fi

    echo ""
    info "启动日志已保存: ${logfile}"
}

# ============================================================
# 验证镜像完整性
# ============================================================
verify_image() {
    header "验证固件镜像"

    local sha256_file="${FW_DIR}/sha256sums"
    if [ ! -f "$sha256_file" ]; then
        warn "未找到 sha256sums 校验文件，跳过校验"
        return
    fi

    info "使用 sha256sums 校验镜像..."
    cd "${FW_DIR}"
    if grep -E "emmc" "${sha256_file}" | sha256sum -c --ignore-missing 2>/dev/null; then
        info "校验通过 ✓"
    else
        warn "部分镜像校验失败，请检查文件完整性"
    fi
    cd "${SCRIPT_DIR}"
}

# ============================================================
# 启动后自动测试函数（通过串口发送命令）
# ============================================================
# 注意：此功能需要 expect 工具
auto_test_after_boot() {
    header "自动功能测试（登录后）"

    if ! command -v expect &>/dev/null; then
        warn "未安装 expect，跳过自动测试"
        echo "  安装: sudo apt install expect"
        return
    fi

    local logfile="$1"
    info "等待系统启动完成（约 60 秒）..."
    sleep 60

    info "发送测试命令..."
    expect <<-EOF
        set timeout 30
        spawn picocom -b ${SERIAL_BAUD} ${SERIAL_DEV}
        expect {
            "login" {
                send "root\r"
                expect "#"
                send "uname -a\r"
                expect "#"
                send "cat /proc/cpuinfo | grep -E 'processor|model name'\r"
                expect "#"
                send "free -m\r"
                expect "#"
                send "df -h\r"
                expect "#"
                send "ip addr\r"
                expect "#"
                send "logread | tail -30\r"
                expect "#"
                send "exit\r"
            }
            timeout {
                puts "超时：未检测到系统启动"
            }
        }
EOF
    info "自动测试完成"
}

# ============================================================
# 主流程
# ============================================================
main() {
    echo ""
    echo -e "${CYAN}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${NC}"
    echo -e "${CYAN}▓${NC}  RK3506 OpenWrt 刷机与启动测试工具                    ${CYAN}▓${NC}"
    echo -e "${CYAN}▓${NC}  固件: HZHY RK3506SP MiniEVM (eMMC)                   ${CYAN}▓${NC}"
    echo -e "${CYAN}▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓${NC}"
    echo ""

    check_prerequisites

    case "${ACTION}" in
        monitor-only)
            monitor_serial
            ;;
        flash-and-monitor)
            if [ "${SKIP_FLASH}" -eq 1 ]; then
                verify_image
                monitor_serial
            else
                echo ""
                warn "请确保开发板已进入 Maskrom/Loader 模式！"
                warn "操作方法：按住 RECOVERY 按钮 → 连接 USB → 上电 → 3秒后松开"
                echo ""
                read -r -p "开发板已进入 Maskrom 模式？[y/N] " confirm
                if [[ ! "$confirm" =~ ^[yY] ]]; then
                    info "已取消刷机，如需仅串口监控请使用 -m 参数"
                    exit 0
                fi

                verify_image
                flash_firmware

                echo ""
                info "刷机完成！请按以下步骤操作："
                echo "  1. 拔掉 USB 线"
                echo "  2. 用 DC 电源适配器给开发板上电"
                echo "  3. 连接串口线（${SERIAL_DEV}, ${SERIAL_BAUD} baud）"
                echo ""
                read -r -p "准备启动监控？[Y/n] " start_mon
                if [[ ! "$start_mon" =~ ^[nN] ]]; then
                    monitor_serial
                fi
            fi
            ;;
    esac
}

main "$@"
