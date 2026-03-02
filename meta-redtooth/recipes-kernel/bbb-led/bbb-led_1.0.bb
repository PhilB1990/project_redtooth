SUMMARY = "BeagleBone Black LED kernel module with sysfs export"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=aa4879e93bb4ca852ed957e3e008434d"

inherit module

# Pull bbb_led.c from linux_drivers/ (avoids duplication)
# append so files/ Makefile takes priority over linux_drivers/ Makefile
FILESEXTRAPATHS:append := ":${THISDIR}/../../../linux_drivers"

SRC_URI = "file://bbb_led.c \
           file://Makefile \
           file://COPYING \
           "

S = "${WORKDIR}"

# Auto-load the module on boot
KERNEL_MODULE_AUTOLOAD += "bbb_led"

RPROVIDES:${PN} += "kernel-module-bbb-led"
