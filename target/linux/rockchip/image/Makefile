# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

DEVICE_VARS += UBOOT_DEVICE_NAME

define Build/Compile
	$(CP) $(LINUX_DIR)/COPYING $(KDIR)/COPYING.linux
endef

define Image/Prepare
	# Copy HZ DTB from KDIR (OpenWrt DTC output) to kernel DTS tree (for mkimage FIT)
	# Runs after compile-dtb (via image_prepare: compile compile-dtb)
	for f in HZ-RK3506SP_MiniEVM_EMMC HZ-RK3506SP_MiniEVM_NAND; do \
		if [ -f "$(KDIR)/image-$$$$f.dtb" ]; then \
			$(CP) "$(KDIR)/image-$$$$f.dtb" "$(DTS_DIR)/rockchip/$$$$f.dtb"; \
		fi; \
	done
endef

### Image scripts ###
define Build/boot-common
	# Create boot folder and copy the kernel image (FIT with embedded DTB)
	rm -fR $@.boot
	mkdir -p $@.boot

	$(CP) $(IMAGE_KERNEL) $@.boot/kernel.img
endef


define Build/boot-script
	# Make an U-boot image and copy it to the boot partition
	mkimage -A arm -O linux -T script -C none -a 0 -e 0 -d $(if $(1),$(1),default).bootscript $@.boot/boot.scr
endef

define Build/pine64-img
	# Creates the final SD/eMMC images, 
	# combining boot partition, root partition as well as the u-boot bootloader

	# Generate a new partition table in $@ with 32 MiB of 
	# alignment padding for the u-boot-rockchip.bin (idbloader + u-boot) to fit:
	# http://opensource.rock-chips.com/wiki_Boot_option#Boot_flow
	#
	# U-Boot SPL expects the U-Boot ITB to be located at sector 0x4000 (8 MiB) on the MMC storage
	PADDING=1 $(SCRIPT_DIR)/gen_image_generic.sh \
		$@ \
		$(CONFIG_TARGET_KERNEL_PARTSIZE) $@.boot \
		$(CONFIG_TARGET_ROOTFS_PARTSIZE) $(IMAGE_ROOTFS) \
		32768

	# Copy the u-boot-rockchip.bin to the image at sector 0x40
	dd if="$(STAGING_DIR_IMAGE)"/$(UBOOT_DEVICE_NAME)-u-boot-rockchip.bin of="$@" seek=64 conv=notrunc
endef


define Build/rk3506-img
	# Creates the final eMMC image for RK3506 (32-bit ARM),
	# combining boot partition, root partition as well as the u-boot bootloader

	# Generate a new partition table in $@ with 32 MiB of 
	# alignment padding for the MiniLoaderAll and u-boot to fit
	#
	# RK3506 boot flow:
	#   BootROM -> MiniLoaderAll (sector 64) -> U-Boot ITB (sector 0x4000) -> Kernel FIT
	PARTOFFSET=16M PADDING=1 $(SCRIPT_DIR)/gen_image_generic.sh \
		$@ \
		$(CONFIG_TARGET_KERNEL_PARTSIZE) $@.boot \
		$(CONFIG_TARGET_ROOTFS_PARTSIZE) $(IMAGE_ROOTFS) \
		32768

	# Copy the MiniLoaderAll (DDR+SPL) to the image at sector 0x40 (64)
	dd if="$(STAGING_DIR_IMAGE)"/$(UBOOT_DEVICE_NAME)-idbloader.img of="$@" seek=64 conv=notrunc
	# Copy the U-Boot ITB to the image at sector 0x4000 (16384)
	dd if="$(STAGING_DIR_IMAGE)"/$(UBOOT_DEVICE_NAME)-u-boot.itb of="$@" seek=16384 conv=notrunc
	# Some vendor SPL builds also probe sector 0x5000 as a fallback.
	dd if="$(STAGING_DIR_IMAGE)"/$(UBOOT_DEVICE_NAME)-u-boot.itb of="$@" seek=20480 conv=notrunc
endef

### Devices ###
define Device/Default
	PROFILES := Default
	KERNEL = kernel-bin | lzma | fit lzma $$(DTS_DIR)/$$(DEVICE_DTS).dtb
	BOOT_SCRIPT :=
	BOOT_FLOW := pine64-img
	IMAGES := sysupgrade.img.gz emmc.img
	IMAGE/sysupgrade.img.gz = boot-common | boot-script $$(BOOT_SCRIPT) | $$(BOOT_FLOW) | gzip | append-metadata
	IMAGE/emmc.img = boot-common | boot-script $$(BOOT_SCRIPT) | $$(BOOT_FLOW)
	DEVICE_DTS = rockchip/$$(SOC)-$(lastword $(subst _, ,$(1)))
	UBOOT_DEVICE_NAME = $(lastword $(subst _, ,$(1)))-$$(SOC)
endef

include $(SUBTARGET).mk

$(eval $(call BuildImage))
