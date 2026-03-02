SUMMARY = "BBB LED web control server"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SYSTEMD_SERVICE:${PN} = "bbb-led-server.service"
SYSTEMD_AUTO_ENABLE = "enable"

SRC_URI = "file://bbb-led-server.c \
           file://index.html \
           file://bbb-led-server.service \
           "

S = "${WORKDIR}"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} -o bbb-led-server bbb-led-server.c
}

do_install() {
    install -d ${D}/var/www
    install -m 0644 ${WORKDIR}/index.html         ${D}/var/www/index.html

    install -d ${D}${sbindir}
    install -m 0755 ${WORKDIR}/bbb-led-server     ${D}${sbindir}/bbb-led-server

    install -d ${D}${systemd_unitdir}/system
    install -m 0644 ${WORKDIR}/bbb-led-server.service \
                    ${D}${systemd_unitdir}/system/bbb-led-server.service
}

FILES:${PN} += "/var/www"
