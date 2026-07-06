# RK3506 OpenWrt 适配说明

## 概述

本目录包含为 Rockchip RK3506 (32位 ARM Cortex-A7) SoC 适配 OpenWrt 的配置文件。
基于 rk-forge (https://github.com/Awesome-Embedded-Learning-Studio/rk-forge) 项目进行适配，
使用主线内核补丁和配置方案。

## 特点

- 移除 arm64 (armv8) 子目标，仅保留 rk3506
- 仅支持 HZ-RK3506SP MiniEVM 设备（EMMC 和 NAND 变体）
- 内核配置基于 rk-forge 的 multi_v7_defconfig + config fragments 方案
- 保留 OpenWrt 的 U-Boot 和镜像打包方式

## 已完成的工作

### 1. Target 配置
- `target/linux/rockchip/rk3506/target.mk` - 32位 ARM 子目标配置
- `target/linux/rockchip/Makefile` - 仅保留 rk3506 子目标

### 2. 内核配置
- `target/linux/rockchip/rk3506/config-6.1` - 内核配置，集成了 rk-forge 项目的配置片段
- `include/kernel-6.1` - 内核版本 6.1.118 信息
- `patches-6.1/` - RK3506 内核补丁，来自 rk-forge 项目适配

### 3. U-Boot 支持
- `package/boot/uboot-rk35xx/Makefile` - 添加 evb-rk3506 变体（32位，无 ATF）
- 使用 rk3506_defconfig，DEFAULT_DEVICE_TREE=rk3506-evb

### 4. rkbin 支持
- `package/boot/rkbin/Makefile` - 添加 rk3506 DDR 固件支持
- DDR 固件：rk3506_ddr_750MHz_v1.04.bin（已复制到 dl/ 目录）

### 5. 镜像打包
- `target/linux/rockchip/image/rk3506.mk` - 设备定义（仅 HZ-RK3506SP 设备）
- `target/linux/rockchip/image/rk3506.bootscript` - U-Boot 启动脚本
- `target/linux/rockchip/image/Makefile` - 添加 rk3506-img 构建步骤

### 6. DTS 文件
- `target/linux/rockchip/files/arch/arm/boot/dts/` - RK3506 基础 DTS 文件
- `target/linux/rockchip/patches-6.1/900-arm-dts-add-rk3506-targets.patch` - DTS Makefile 补丁

## 待完成的工作

### 关键：生成完整的内核补丁

RK3506 的支持代码在主线内核 6.1 中不存在，需要从 Ubuntu SDK 内核生成补丁：

```bash
# 1. 下载主线内核 6.1.118
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.1.118.tar.xz
tar xf linux-6.1.118.tar.xz

# 2. 生成 RK3506 相关补丁
# 比较 rk3506-ubuntu/kernel-6.1 和主线内核
# 提取以下目录的差异：
#   - arch/arm/boot/dts/rk3506*
#   - arch/arm/mach-rockchip/
#   - drivers/clk/rockchip/
#   - drivers/gpu/drm/rockchip/
#   - drivers/pinctrl/
#   - drivers/net/ethernet/stmicro/stmmac/
#   - drivers/phy/rockchip/
#   - drivers/mmc/host/dw_mmc-rockchip*
#   - include/dt-bindings/

# 3. 将补丁放入 target/linux/rockchip/patches-6.1/
```

### 板级 DTS 定制

当前的板级 DTS 文件是基于 EVB 的参考实现：
- `target/linux/rockchip/files/arch/arm/boot/dts/rk3506b-luckfox-lyra-pi-w-sd.dts`
- `target/linux/rockchip/files/arch/arm/boot/dts/rk3506-armsom-forge1.dts`

需要根据实际硬件配置调整：
- 以太网 PHY 地址和类型
- LED 配置
- GPIO 按键
- WiFi/BT 模块
- 显示接口

### 内核配置微调

```bash
# 编译后可运行 menuconfig 调整内核配置
make kernel_menuconfig CONFIG_TARGET=rk3506
```

## 构建方法

```bash
# 1. 更新 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 2. 选择 RK3506 目标
make menuconfig
# Target System: Rockchip
# Subtarget: RK3506 boards (32 bit)
# Target Profile: 选择 Luckfox Lyra 或 ArmSoM Forge1

# 3. 编译
make -j$(nproc) V=s
```

## 启动流程

```
BootROM -> MiniLoaderAll (DDR+SPL, sector 64)
        -> U-Boot ITB (sector 0x4000)
        -> boot.scr (distro_bootcmd, boot 分区 mmc:1)
        -> OpenWrt FIT Image (zImage + DTB, lzma 解压至 0x03200000)
        -> zImage 自解压内核至 0x00008000, DTB 载入 0x02000000
        -> Rootfs (squashfs + overlay, mmc:2)
```

说明：
- RK3506 为 32 位 ARM (Cortex-A7)，内核以自解压的 `zImage` 形式打包进 FIT
  （`KERNEL_NAME := zImage`，子目标 `KERNELNAME:=zImage dtbs`）。裸 `Image`
  不可重定位，在高位加载地址 `0x03200000` 入口会在早期 `head.S` 卡死。
- FDT 载入地址设为 `0x02000000`，位于自解压内核（`0x00008000` 起）之上，
  避免被内核解压覆盖。

说明：
- U-Boot SPL 从裸扇区 `0x4000`（对应 `dd seek=16384`）加载 `u-boot.itb`，
  已在 `package/boot/uboot-rk35xx/Makefile` 中关闭
  `CONFIG_SYS_MMCSD_RAW_MODE_U_BOOT_USE_PARTITION` 并设定
  `CONFIG_SYS_MMCSD_RAW_MODE_U_BOOT_SECTOR=0x4000`，使 SPL 的加载位置与镜像布局一致。
- U-Boot proper 使用 `distro_bootcmd` 扫描启动分区（ext4，需要 `CONFIG_CMD_EXT4`/
  `CONFIG_FS_EXT4`）并执行 `boot.scr`，再 `bootm` 引导 FIT 内核。

## 参考

- 同级目录：`../rk3506-ubuntu/` - Ubuntu SDK 打包参考
- 分区布局：参考 `rk3506-ubuntu/device/rockchip/rk3506/parameter-lyra-sdmmc.txt`
- U-Boot 配置：`rk3506-ubuntu/u-boot/configs/rk3506_luckfox_defconfig`
- 内核配置：`rk3506-ubuntu/kernel-6.1/arch/arm/configs/rk3506_luckfox_defconfig`
