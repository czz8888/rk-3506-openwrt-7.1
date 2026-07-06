# RK3506 OpenWrt 适配说明（测试阶段）

> ⚠️ **重要提示：当前 RK3506 的 OpenWrt 支持尚不完善，仍处于早期测试阶段，不可用于生产环境。**
>
> 这是 **第一份** 基于 OpenWrt 的 RK3506 (32位 ARM Cortex-A7) 构建尝试。
> 由于 RK3506 在主线内核中缺乏完善支持，很多功能可能无法正常工作，
> 构建流程和配置文件也在持续迭代中。欢迎测试反馈，但请勿在生产场景下使用。

## 概述

本目录包含为 Rockchip RK3506 (32位 ARM Cortex-A7) SoC 适配 OpenWrt 的实验性配置文件。
适配工作基于 [rk-forge](https://github.com/Awesome-Embedded-Learning-Studio/rk-forge) 项目
的内核补丁和配置方案进行，属于社区驱动的探索性尝试，**非 Rockchip 官方支持**。

由于主线 Linux 内核尚未完整支持 RK3506，当前方案通过从 Ubuntu SDK 内核中提取补丁的方式
来使能基本的硬件支持。这意味着底层驱动可能存在未知问题，部分外设功能尚未验证。

## 当前状态：测试中 🧪

目前仅做了以下基础适配，**尚不能保证系统能正常启动和稳定运行**：

- ✅ 32位 ARM (armv7) 子目标配置框架搭建完成
- ✅ 基于 rk-forge 的内核配置初步集成
- ✅ U-Boot evb-rk3506 变体构建支持
- ✅ DDR 固件 (rk3506_ddr_750MHz_v1.04.bin) 集成
- ✅ 镜像打包脚本和启动脚本初版
- ⚠️ 内核补丁**尚未验证完整性**，需从 Ubuntu SDK 内核重新生成
- ⚠️ 仅对 HZ-RK3506SP MiniEVM (EMMC/NAND) 做过初步适配
- ⚠️ 网络、显示、音频等外设功能未全面测试

## 已修改的文件清单

### 1. Target 配置
- `target/linux/rockchip/rk3506/target.mk` - 32位 ARM 子目标配置
- `target/linux/rockchip/Makefile` - 仅保留 rk3506 子目标

### 2. 内核配置
- `target/linux/rockchip/rk3506/config-6.1` - 内核配置，集成了 rk-forge 项目的配置片段
- `patches-6.1/` - RK3506 内核补丁（来源：rk-forge 项目，需验证完整性）

### 3. U-Boot 支持
- `package/boot/uboot-rk35xx/Makefile` - 添加 evb-rk3506 变体（32位，无 ATF）
- 使用 `rk3506_defconfig`，`DEFAULT_DEVICE_TREE=rk3506-evb`

### 4. rkbin 支持
- `package/boot/rkbin/Makefile` - 添加 rk3506 DDR 固件支持
- DDR 固件：`rk3506_ddr_750MHz_v1.04.bin`（已放入 `dl/` 目录）

### 5. 镜像打包
- `target/linux/rockchip/image/rk3506.mk` - 设备定义（仅 HZ-RK3506SP MiniEVM）
- `target/linux/rockchip/image/rk3506.bootscript` - U-Boot 启动脚本
- `target/linux/rockchip/image/Makefile` - 添加 `rk3506-img` 构建步骤

### 6. DTS 文件
- `target/linux/rockchip/files/arch/arm/boot/dts/` - RK3506 基础 DTS 文件
- `target/linux/rockchip/patches-6.1/900-arm-dts-add-rk3506-targets.patch` - DTS Makefile 补丁

## 已知问题和待办事项

### 🔴 高优先级

**1. 重新生成并验证内核补丁**

RK3506 的支持代码在主线内核 6.1 中**不存在**，当前补丁来自 rk-forge 项目的初步提取，
需要从 Ubuntu SDK 内核重新生成完整补丁：

```bash
# 1. 获取主线内核 6.1.118
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.1.118.tar.xz
tar xf linux-6.1.118.tar.xz

# 2. 对比 Ubuntu SDK 内核与主线，生成补丁
# 重点关注以下目录的差异：
#   - arch/arm/boot/dts/rk3506*
#   - arch/arm/mach-rockchip/
#   - drivers/clk/rockchip/
#   - drivers/gpu/drm/rockchip/
#   - drivers/pinctrl/
#   - drivers/net/ethernet/stmicro/stmmac/
#   - drivers/phy/rockchip/
#   - drivers/mmc/host/dw_mmc-rockchip*
#   - include/dt-bindings/

# 3. 将生成的补丁放入 target/linux/rockchip/patches-6.1/
```

**2. 验证系统启动**

- 在实际硬件上测试镜像能否正常启动
- 验证串口输出，确认内核和 rootfs 挂载正常
- 排查可能的内核 panic 或驱动缺失

### 🟡 中优先级

**3. 板级 DTS 定制**

当前板级 DTS 基于 EVB 参考实现，需要根据实际硬件调整：
- `rk3506b-luckfox-lyra-pi-w-sd.dts`
- `rk3506-armsom-forge1.dts`

需按实际硬件配置的项目：
- 以太网 PHY 地址和类型
- LED / GPIO 按键配置
- 电源管理和休眠唤醒

**4. 外设功能验证**

- 网络 (Ethernet/WiFi)
- USB 主机/设备模式
- 显示输出 (DRM/GPU)
- 音频 (I2S/Codec)
- MMC/SD 卡稳定性

### 🟢 低优先级

**5. 多设备支持扩展**

目前仅适配了 HZ-RK3506SP MiniEVM，后续可考虑支持：
- Luckfox Lyra Pi W
- ArmSoM Forge1
- 其他 RK3506 开发板

**6. 内核版本升级**

考虑跟进更新的 LTS 内核版本（如 6.6），以获取更好的主线支持。

## 贡献和反馈

这是一个社区驱动的实验项目，欢迎任何形式的贡献：
- 在实际硬件上测试并报告结果
- 提交内核补丁修复或功能增强
- 分享设备树配置和调试经验

请在提交 issue 时附带完整的串口日志和复现步骤，以便定位问题。
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
