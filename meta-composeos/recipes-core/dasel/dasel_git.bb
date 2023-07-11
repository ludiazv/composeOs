DESCRIPTION = "Dasel (short for data-selector) allows you to query and modify data structures using selector strings"
SECTION = "composeOS"
HOMEPAGE = "https://github.com/TomWright/dasel"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

#inherit go-mod
#
#SRC_URI = "git://${GO_IMPORT}.git;branch=master;protocol=https"
#SRC_URI[sha256sum] = "895fcde3dfeb4d199a398b100ab4701b75c4b12c9942930e2932a19850508a2c"
##SRC_REV = "3b466e8"
#SRCREV = "3b466e80eabf70b6b39aadb99e43f5fff57ea2ae"
##SRC_REV = "${AUTOREV}"
#
#PV = "2.2.0+git${SRCPV}"
#
#GO_IMPORT ="github.com/TomWright/dasel"
#S = "${WORKDIR}/git"

SRC_URI += " https://github.com/TomWright/dasel/releases/download/v2.1.1/dasel_linux_arm64;name=arm64"
SRC_URI += " https://github.com/TomWright/dasel/releases/download/v2.1.2/dasel_linux_arm32;name=arm32"
SRC_URI[arm64.sha256sum] = "7da843ff0e043e893a78c489f9e97e9332339816dec642ee90d60b3b08980e89"
SRC_URI[arm32.sha256sum] = "337d1880b60580f4c72be1711d345d62d62c79cd59a9a12f8cc041d6d087544a"

do_install() {
    # Binaries
    install -d ${D}${bindir}
    if [ ${TARGET_ARCH} = "aarch64" ] ; then
        install -m 0755 ${WORKDIR}/dasel_linux_arm64 ${D}${bindir}/dasel
    else
        install -m 0755 ${WORKDIR}/dasel_linux_arm32 ${D}${bindir}/dasel
    fi
}
