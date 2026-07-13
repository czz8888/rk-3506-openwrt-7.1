# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2021-2023 ImmortalWrt.org

include $(TOPDIR)/rules.mk

PKG_NAME:=rkbin
PKG_RELEASE:=1

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/rockchip-linux/rkbin.git
PKG_SOURCE_DATE:=2025-12-30
PKG_SOURCE_VERSION:=ecb4fcbe954edf38b3ae037d5de6d9f5bccf81f4
PKG_MIRROR_HASH:=2711996a62d6a67948a3a4e8acc7b8e928a83b4612de983ff2448e509c794180

PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=Tianling Shen <cnsztl@immortalwrt.org>

include $(INCLUDE_DIR)/kernel.mk
include $(INCLUDE_DIR)/trusted-firmware-a.mk
include $(INCLUDE_DIR)/package.mk

define Trusted-Firmware-A/Default
  NAME:=Rockchip $(1) SoCs
  BUILD_TARGET:=rockchip
endef

define Trusted-Firmware-A/rk3308
  BUILD_SUBTARGET:=armv8
  ATF:=rk33/rk3308_bl31_v2.26.elf
  TPL:=rk33/rk3308_ddr_589MHz_uart2_m1_v2.07.bin
endef

define Trusted-Firmware-A/rk3308-rock-pi-s
  NAME:=Radxa ROCK Pi S
  BUILD_SUBTARGET:=armv8
  ATF:=rk33/rk3308_bl31_v2.26.elf
  TPL:=rk33/rk3308_ddr_589MHz_uart0_m0_v2.07.bin
endef

define Trusted-Firmware-A/rk3566
  BUILD_SUBTARGET:=armv8
  ATF:=rk35/rk3568_bl31_v1.44.elf
  TPL:=rk35/rk3566_ddr_1056MHz_v1.21.bin
endef

define Trusted-Firmware-A/rk3568
  BUILD_SUBTARGET:=armv8
  ATF:=rk35/rk3568_bl31_v1.44.elf
  TPL:=rk35/rk3568_ddr_1560MHz_v1.21.bin
endef

define Trusted-Firmware-A/rk3568-e25
  NAME:=Radxa E25 board
  BUILD_SUBTARGET:=armv8
  ATF:=rk35/rk3568_bl31_v1.44.elf
  TPL:=rk35/rk3568_ddr_1560MHz_uart2_m0_115200_v1.21.bin
endef

define Trusted-Firmware-A/rk3588
  BUILD_SUBTARGET:=armv8
  ATF:=rk35/rk3588_bl31_v1.45.elf
  TPL:=rk35/rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.16.bin
endef

define Trusted-Firmware-A/rk3506
  BUILD_SUBTARGET:=rk3506
  NAME:=Rockchip RK3506 SoCs
  TOS:=rk35/rk3506_tee_v2.40.bin
  TPL:=rk35/rk3506_ddr_750MHz_v1.06.bin
  # rkbin prebuilt SPL (v1.12) — the known-good reference that correctly
  # enters OP-TEE for PSCI / secondary-CPU bringup. The U-Boot-self-built SPL
  # (SPL_OPTEE path) loads OP-TEE but fails PSCI on RK3506; the rkbin SPL is
  # the proven chain (rk-forge boots all 3 Cortex-A7 cores with it). Consumed
  # by uboot-rk35xx as the idbloader FlashBoot.
  SPL:=rk35/rk3506_spl_v1.12.bin
endef

TFA_TARGETS:= \
	rk3308 \
	rk3308-rock-pi-s \
	rk3566 \
	rk3568 \
	rk3568-e25 \
	rk3588 \
	rk3506

ifeq ($(BUILD_VARIANT),rk3308-rock-pi-s)
  TPL_FILE:=rk3308_ddr_589MHz_uart0_m0_v2.07.bin
  define Download/rk3308-tpl-rock-pi-s
    FILE:=$(TPL_FILE)
    URL:=https://github.com/radxa/rkbin/raw/5696fab20dcac57c1458f72dc7604ba60e553adf/bin/rk33/
    HASH:=8a1a42df23cccb86a2dabc14a5c0e9227d64a51b9b83e9968ef5af3b30787f7d
  endef

  define Build/Prepare
	$(eval $(call Download,rk3308-tpl-rock-pi-s))
	$(call Build/Prepare/Default)

	$(CP) $(DL_DIR)/$(TPL_FILE) $(PKG_BUILD_DIR)/bin/rk33/
  endef
endif

ifeq ($(BUILD_VARIANT),rk3568-e25)
  TPL_FILE:=rk3568_ddr_1560MHz_uart2_m0_115200_v1.21.bin
  define Download/rk3568-tpl-e25
    FILE:=$(TPL_FILE)
    URL:=https://github.com/radxa/rkbin/raw/5696fab20dcac57c1458f72dc7604ba60e553adf/bin/rk35/
    HASH:=1815f9649dc5661a3ef184b052da39286e51453a66f6ff53cc3e345d65dfabd4
  endef

  define Build/Prepare
	$(eval $(call Download,rk3568-tpl-e25))
	$(call Build/Prepare/Default)

	$(CP) $(DL_DIR)/$(TPL_FILE) $(PKG_BUILD_DIR)/bin/rk35/
  endef
endif

ifeq ($(BUILD_VARIANT),rk3506)
  TPL_FILE:=rk3506_ddr_750MHz_v1.06.bin
  TOS_FILE:=rk3506_tee_v2.40.bin
  SPL_FILE:=rk3506_spl_v1.12.bin
  define Download/rk3506-tpl
    FILE:=$(TPL_FILE)
    URL:=https://github.com/rockchip-linux/rkbin/raw/master/bin/rk35/
    HASH:=394172ce23b8f3b966a03a296a7c86d616e1463b781f44901c16f8faa8f6ca64
  endef
  define Download/rk3506-tos
    FILE:=$(TOS_FILE)
    URL:=https://github.com/rockchip-linux/rkbin/raw/master/bin/rk35/
    HASH:=e2a712a5330df72daa4e5c8900e98aa85e0880d0cc0e551f1fb18eb27488da2d
  endef
  define Download/rk3506-spl
    FILE:=$(SPL_FILE)
    URL:=https://github.com/rockchip-linux/rkbin/raw/master/bin/rk35/
    HASH:=d1d14e45cec200366d184be1be20cd58e820e5c6799f25b2e2b3994cff145514
  endef

  define Build/Prepare
	$(eval $(call Download,rk3506-tpl))
	$(eval $(call Download,rk3506-tos))
	$(eval $(call Download,rk3506-spl))
	$(call Build/Prepare/Default)

	$(CP) $(DL_DIR)/$(TPL_FILE) $(PKG_BUILD_DIR)/bin/rk35/
	$(CP) $(DL_DIR)/$(TOS_FILE) $(PKG_BUILD_DIR)/bin/rk35/
	$(CP) $(DL_DIR)/$(SPL_FILE) $(PKG_BUILD_DIR)/bin/rk35/
  endef
endif

define Build/Compile
endef

define Package/trusted-firmware-a/install
	$(INSTALL_DIR) $(STAGING_DIR_IMAGE)

ifneq ($(ATF),)
	$(CP) $(PKG_BUILD_DIR)/bin/$(ATF) $(STAGING_DIR_IMAGE)/
endif
ifneq ($(TOS),)
	$(CP) $(PKG_BUILD_DIR)/bin/$(TOS) $(STAGING_DIR_IMAGE)/
endif
ifneq ($(TPL),)
	$(CP) $(PKG_BUILD_DIR)/bin/$(TPL) $(STAGING_DIR_IMAGE)/
endif
ifneq ($(SPL),)
	$(CP) $(PKG_BUILD_DIR)/bin/$(SPL) $(STAGING_DIR_IMAGE)/
endif
endef

$(eval $(call BuildPackage/Trusted-Firmware-A))
