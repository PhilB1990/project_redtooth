FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

do_configure:append() {
    sed -i "s/^# CONFIG_FEATURE_NC_SERVER is not set/CONFIG_FEATURE_NC_SERVER=y/" ${B}/.config
    grep -q "^CONFIG_FEATURE_NC_SERVER=y" ${B}/.config || echo "CONFIG_FEATURE_NC_SERVER=y" >> ${B}/.config
}

do_compile:prepend() {
    if [ -f ${B}/include/autoconf.h ]; then
        sed -i "/CONFIG_FEATURE_NC_SERVER/d" ${B}/include/autoconf.h
        echo "#define CONFIG_FEATURE_NC_SERVER 1" >> ${B}/include/autoconf.h
    fi
}
