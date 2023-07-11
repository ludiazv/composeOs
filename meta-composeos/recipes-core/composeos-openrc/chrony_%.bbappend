FILESEXTRAPATHS:prepend := "${THISDIR}/chrony:"

SRC_URI:append = " \
    file://chronyd.initd \
    file://chronyd.confd \
    file://chrony-wait.initd \
    file://chrony-wait.confd \
"

LICENSE += "${@bb.utils.contains('DISTRO_FEATURES', 'openrc', '& GPL-2.0-only', '', d)}"

inherit openrc

OPENRC_SERVICES:${PN} = "chronyd chrony-wait"

RDEPENDS:${PN}:append = " chronyc"

do_install:append() {
    openrc_install_initd ${WORKDIR}/chronyd.initd
    openrc_install_confd ${WORKDIR}/chronyd.confd
    openrc_install_initd ${WORKDIR}/chrony-wait.initd
    openrc_install_confd ${WORKDIR}/chrony-wait.confd
}
