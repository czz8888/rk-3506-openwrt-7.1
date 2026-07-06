ARCH:=arm
SUBTARGET:=rk3506
BOARDNAME:=RK3506 boards (32 bit)
CPU_TYPE:=cortex-a7
CPU_SUBTYPE:=vfpv4

# 32-bit ARM needs a self-decompressing, position-independent zImage. A raw
# "Image" is not relocatable and cannot be entered at the high, non-16MiB
# aligned load address (0x03200000) used by the vendor U-Boot boot flow.
KERNELNAME:=zImage dtbs

KERNEL_PATCHVER:=7.1

# Kernel 7.1 from rk-forge (linux-stable v7.1)
# RK3506 SoC support is mainlined since kernel 6.19+

define Target/Description
	Build firmware image for Rockchip RK3506 devices.
	This firmware features a 32 bit kernel.
endef
