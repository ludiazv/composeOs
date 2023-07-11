DESCRIPTION = "composeOS openrc service scripts - boot and run"
SECTION = "composeOS"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# Source files to package
SRC_URI += " file://composeos-boot.initd \
             file://composeos-boot.confd \
             file://composeos-run.initd \
             file://composeos-run.confd \
           "

RDEPENDS:${PN}:append = " composeoslib"
#RDEPENDS:${PN}:append = " openrc"

# use oe update rc class
inherit openrc

# define services to enable and run level
OPENRC_SERVICES:${PN} = "composeos-boot composeos-run"
OPENRC_AUTO_ENABLE:${PN} = "enabled enabled"
OPENRC_RUNLEVEL:${PN} = "boot default"

do_install() {
    openrc_install_initd ${WORKDIR}/composeos-boot.initd
    openrc_install_confd ${WORKDIR}/composeos-boot.confd
    openrc_install_initd ${WORKDIR}/composeos-run.initd
    openrc_install_confd ${WORKDIR}/composeos-run.confd

    #install -d ${D}${sysconfdir}/init.dV
    #install -m 755 ${WORKDIR}/composeos-boot.initd ${D}${sysconfdir}/init.d/composeos-boot
    
    #install -d ${D}${sysconfdir}/conf.d
    #install -m 644 ${WORKDIR}/composeos-boot.confd ${D}${sysconfdir}/conf.d/composeos-boot
    #openrc_install_initd ${WORKDIR}/composeos-run.initd
    #openrc_install_confd ${WORKDIR}/composeos-run.confd
} 

#FILES:${PN}= "${sysconfdir}/init.d/composeos-boot ${sysconfdir}/conf.d/composeos-boot"

