#
# Copyright (C) 2022 ImmortalWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=uboot-rk35xx
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/radxa/u-boot

PKG_SOURCE_DATE:=2024-10-29
PKG_SOURCE_VERSION:=27398f1e19628407fabb279034653d23c9369f12
PKG_MIRROR_HASH:=b8f7755af005afff2dbfea3e8b54d380734c43ac09017bff1d86e1adcfca7c77

include $(INCLUDE_DIR)/u-boot.mk
include $(INCLUDE_DIR)/package.mk

define U-Boot/Default
  BUILD_TARGET:=rockchip
  UENV:=default
  HIDDEN:=1
endef

define U-Boot/evb-rk3528
  BUILD_SUBTARGET:=armv8
  NAME:=RK3528 Evaluation
  BUILD_DEVICES:= \
    armsom_sige1
  DEPENDS:=+PACKAGE_u-boot-evb-rk3528:rkbin-rk3528
  ATF:=rk3528_bl31_v1.17.elf
  DDR:=rk3528_ddr_1056MHz_v1.10.bin
  UBOOT_CONFIG:=rk3528
  SOC:=rk3528
endef

define U-Boot/evb-rk3576
  BUILD_SUBTARGET:=armv8
  NAME:=RK3576 Evaluation
  BUILD_DEVICES:= \
    100ask_dshanpi-a1 \
    armsom_sige5 \
    ariaboard_photonicat2 \
    friendlyarm_nanopi-m5 \
    friendlyarm_nanopi-r76s
  DEPENDS:=+PACKAGE_u-boot-evb-rk3576:rkbin-rk3576
  ATF:=rk3576_bl31_v1.12.elf
  DDR:=rk3576_ddr_lp4_2112MHz_lp5_2736MHz_v1.08.bin
  UBOOT_CONFIG:=rk3576
  SOC:=rk3576
endef

define U-Boot/evb-rk3506
  BUILD_SUBTARGET:=rk3506
  NAME:=RK3506 Evaluation
  BUILD_DEVICES:= \
    luckfox_lyra \
    armsom_forge1 \
    hzhy_mini_evm_emmc \
    hzhy_mini_evm_nand
  DEPENDS:=+PACKAGE_u-boot-evb-rk3506:trusted-firmware-a-rk3506
  TOS:=rk3506_tee_v2.40.bin
  DDR:=rk3506_ddr_750MHz_v1.06.bin
  # rkbin prebuilt SPL (installed to STAGING_DIR_IMAGE by trusted-firmware-a-rk3506)
  # used as the idbloader FlashBoot — see package/boot/rkbin for why.
  SPL:=rk3506_spl_v1.12.bin
  UBOOT_CONFIG:=rk3506
  SOC:=rk3506
endef

# Locally limited to the 32-bit rk3506 variant. The evb-rk3528 / evb-rk3576
# variants are ARM64 and cannot build with this target's 32-bit ARM toolchain
# (cc1: error: unknown register name: x18). Main builds all three
# unconditionally — flag to friend (gate ARM64 variants on an aarch64 toolchain
# or skip them for the 32-bit rk3506 target).
UBOOT_TARGETS := \
  evb-rk3506

UBOOT_CONFIGURE_VARS += USE_PRIVATE_LIBGCC=yes

# Build targets: for 64-bit SoCs with ATF, include BL31; for 32-bit RK3506 with OP-TEE, include TOS
ifneq ($(ATF),)
  UBOOT_MAKE_FLAGS += \
    BL31=$(STAGING_DIR_IMAGE)/$(ATF) spl/u-boot-spl.bin u-boot.dtb u-boot.itb
else ifneq ($(TOS),)
  UBOOT_MAKE_FLAGS += \
    TOS_BIN=$(STAGING_DIR_IMAGE)/$(TOS) spl/u-boot-spl.bin u-boot.dtb u-boot.itb
else
  UBOOT_MAKE_FLAGS += \
    spl/u-boot-spl.bin u-boot.dtb u-boot.itb
endif

define Build/Configure
	$(call Build/Configure/U-Boot)

	$(SED) 's#CONFIG_MKIMAGE_DTC_PATH=.*#CONFIG_MKIMAGE_DTC_PATH="$(PKG_BUILD_DIR)/scripts/dtc/dtc"#g' $(PKG_BUILD_DIR)/.config
	echo 'CONFIG_IDENT_STRING=" OpenWrt"' >> $(PKG_BUILD_DIR)/.config

	# RK3506: add mkimage support, enable OP-TEE, use default FIT generator
	if grep -q 'CONFIG_ROCKCHIP_RK3506=y' $(PKG_BUILD_DIR)/.config; then \
		$(SED) '/{ "rk3528", "RK35"/i { "rk3506", "RK35", 0x10000 - 0x1000, false, RK_HEADER_V2 },' $(PKG_BUILD_DIR)/tools/rkcommon.c ; \
		$(SED) 's/CONFIG_ANDROID_BOOTLOADER=y/# CONFIG_ANDROID_BOOTLOADER is not set/' $(PKG_BUILD_DIR)/.config ; \
		$(SED) 's/CONFIG_ANDROID_BOOT_IMAGE=y/# CONFIG_ANDROID_BOOT_IMAGE is not set/' $(PKG_BUILD_DIR)/.config ; \
		$(SED) 's/CONFIG_CMD_BOOT_ANDROID=y/# CONFIG_CMD_BOOT_ANDROID is not set/' $(PKG_BUILD_DIR)/.config ; \
		$(SED) 's/CONFIG_ANDROID_BOOT_IMAGE_HASH=y/# CONFIG_ANDROID_BOOT_IMAGE_HASH is not set/' $(PKG_BUILD_DIR)/.config ; \
		$(SED) 's/CONFIG_SPL_AB=y/# CONFIG_SPL_AB is not set/' $(PKG_BUILD_DIR)/.config ; \
		$(SED) 's/CONFIG_ROCKCHIP_VENDOR_PARTITION=y/# CONFIG_ROCKCHIP_VENDOR_PARTITION is not set/' $(PKG_BUILD_DIR)/.config ; \
		$(SED) 's/CONFIG_SF_DEFAULT_MODE=.*/CONFIG_SF_DEFAULT_MODE=0/' $(PKG_BUILD_DIR)/.config ; \
		echo 'CONFIG_CMD_FS_GENERIC=y' >> $(PKG_BUILD_DIR)/.config ; \
		echo 'CONFIG_CMD_FS_UUID=y' >> $(PKG_BUILD_DIR)/.config ; \
		echo '# CONFIG_RKIMG_BOOTLOADER is not set' >> $(PKG_BUILD_DIR)/.config ; \
		echo '# CONFIG_ROCKCHIP_BOOT_MODE_REGULATOR is not set' >> $(PKG_BUILD_DIR)/.config ; \
		$(SED) 's/^static void \*bitmap_create/static __maybe_unused void *bitmap_create/' $(PKG_BUILD_DIR)/drivers/video/drm/rockchip_display.c ; \
		$(SED) 's/^static unsigned char \*bitmap_get_buffer/static __maybe_unused unsigned char *bitmap_get_buffer/' $(PKG_BUILD_DIR)/drivers/video/drm/rockchip_display.c ; \
		$(SED) 's/^static void bitmap_destroy/static __maybe_unused void bitmap_destroy/' $(PKG_BUILD_DIR)/drivers/video/drm/rockchip_display.c ; \
		$(SED) 's/^static void bmp_copy/static __maybe_unused void bmp_copy/' $(PKG_BUILD_DIR)/drivers/video/drm/rockchip_display.c ; \
		$(SED) 's/^static void \*rockchip_logo_rotate/static __maybe_unused void *rockchip_logo_rotate/' $(PKG_BUILD_DIR)/drivers/video/drm/rockchip_display.c ; \
		$(SED) 's/^\tTEE_OFFSET=0x08400000/\tTEE_OFFSET=0x1000/' $(PKG_BUILD_DIR)/arch/arm/mach-rockchip/fit_args.sh ; \
		$(SED) 's/#define CONFIG_SYS_TEXT_BASE[[:space:]]*0x00200000/#define CONFIG_SYS_TEXT_BASE\t0x00800000/' $(PKG_BUILD_DIR)/include/configs/rk3506_common.h ; \
		cp -f $(STAGING_DIR_IMAGE)/$(TOS) $(PKG_BUILD_DIR)/tee.bin ; \
		$(SED) 's/"boot_fit;"[[:space:]]*\\/"run distro_bootcmd;"/' $(PKG_BUILD_DIR)/include/configs/rk3506_common.h ; \
		$(SED) '/boot_android/d' $(PKG_BUILD_DIR)/include/configs/rk3506_common.h ; \
		echo 'CONFIG_CMD_PART=y' >> $(PKG_BUILD_DIR)/.config ; \
		echo 'CONFIG_CMD_FAT=y' >> $(PKG_BUILD_DIR)/.config ; \
		echo 'CONFIG_FS_FAT=y' >> $(PKG_BUILD_DIR)/.config ; \
		echo 'CONFIG_FAT_WRITE=y' >> $(PKG_BUILD_DIR)/.config ; \
		echo 'CONFIG_CMD_EXT4=y' >> $(PKG_BUILD_DIR)/.config ; \
		echo 'CONFIG_FS_EXT4=y' >> $(PKG_BUILD_DIR)/.config ; \
		echo 'CONFIG_CMD_SOURCE=y' >> $(PKG_BUILD_DIR)/.config ; \
		$(SED) 's/CONFIG_SYS_MMCSD_RAW_MODE_U_BOOT_USE_PARTITION=y/# CONFIG_SYS_MMCSD_RAW_MODE_U_BOOT_USE_PARTITION is not set/' $(PKG_BUILD_DIR)/.config ; \
		echo 'CONFIG_SYS_MMCSD_RAW_MODE_U_BOOT_SECTOR=0x4000' >> $(PKG_BUILD_DIR)/.config ; \
	fi
endef

define Build/InstallDev
	$(INSTALL_DIR) $(STAGING_DIR_IMAGE)
	# idbloader = rkbin DDR (TPL) + rkbin prebuilt SPL (FlashBoot).
	# Use the rkbin prebuilt SPL ($(SPL), installed by trusted-firmware-a-rk3506)
	# instead of the U-Boot-self-built spl/u-boot-spl.bin: the U-Boot SPL's
	# SPL_OPTEE path loads OP-TEE but fails PSCI/secondary-CPU bringup on
	# RK3506, while the rkbin SPL correctly enters OP-TEE for PSCI (proven by
	# rk-forge, which boots all 3 Cortex-A7 cores). The FIT (u-boot.itb) is
	# unchanged — radxa make_fit_optee.sh already emits firmware=optee;
	# loadables=uboot, which the rkbin SPL consumes. The V2-header SPL load
	# address patched below (0x03f00000) matches the rkbin SPL's LOAD_ADDR.
	$(PKG_BUILD_DIR)/tools/mkimage -n $(SOC) -T rksd -d \
		$(STAGING_DIR_IMAGE)/$(DDR):$(STAGING_DIR_IMAGE)/$(SPL) $(PKG_BUILD_DIR)/idbloader.img
	# RK3506: fix SPL load address in V2 idbloader header
	# mkimage hardcodes images[1].address=0xFFFFFFFF but RK3506 BootROM
	# requires the actual CONFIG_SPL_TEXT_BASE (0x03f00000) to load SPL.
	# V2 header layout: images[1].address is at offset 0xd4 (212 decimal).
	# Only patch when the 4 bytes at that offset are still the mkimage
	# placeholder (ff ff ff ff); if a future mkimage changes the header
	# layout the bytes will differ and we abort instead of corrupting it.
	if [ "$(SOC)" = "rk3506" ]; then \
		placeholder="$$$$(dd if=$(PKG_BUILD_DIR)/idbloader.img bs=1 skip=212 count=4 2>/dev/null | od -An -tx1 | tr -d ' \n')"; \
		if [ "$$$$placeholder" = "ffffffff" ]; then \
			printf '\x00\x00\xf0\x03' | dd of=$(PKG_BUILD_DIR)/idbloader.img bs=1 seek=212 count=4 conv=notrunc 2>/dev/null; \
		else \
			echo "ERROR: unexpected idbloader V2 header at offset 212: expected ffffffff, got '$$$$placeholder'. Refusing to patch SPL load address to prevent header corruption." >&2; \
			exit 1; \
		fi; \
	fi
	$(CP) $(PKG_BUILD_DIR)/idbloader.img $(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-idbloader.img
	$(CP) $(PKG_BUILD_DIR)/u-boot.itb $(STAGING_DIR_IMAGE)/$(BUILD_VARIANT)-u-boot.itb
endef

define Package/u-boot/install/default
endef

$(eval $(call BuildPackage/U-Boot))
