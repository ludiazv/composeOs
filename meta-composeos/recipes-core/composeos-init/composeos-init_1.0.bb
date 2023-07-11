DESCRIPTION = "composeOS init scripts"
SECTION = "composeOS"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# Source files to package
SRC_URI += " file://composeos-init.sh"

RDEPENDS:${PN} += " composeoslib"

# Setup init script variables for update-rc.d class
INITSCRIPT_NAME ="composeos-init.sh"
INITSCRIPT_PARAMS ="start 39 S ."

# use oe update rc class
inherit update-rc.d

do_install() {

    # System V init script
    install -d ${D}${sysconfdir}/init.d
    install -m 755 ${WORKDIR}/composeos-init.sh ${D}${sysconfdir}/init.d
}

FILES_${PN} = "${sysconfdir}/init.d/composeos-init.sh"
