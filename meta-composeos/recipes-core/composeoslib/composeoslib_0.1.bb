DESCRIPTION = "composeOS core library and scripts"
SECTION = "composeOS"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# Source files to package
SRC_URI += " file://base.sh \
             file://boot.sh \
             file://bootrc.sh \
             file://run.sh \
             file://runrc.sh \
             file://net.sh \
             file://json.sh \
             file://log.sh \
             file://udhcpc.sh \
             file://composeos.conf \
             file://env \
             file://cos.sh \
           "

# External tools that are required for the script to work
RDEPENDS:${PN}:append = " dasel jq iproute2 e2fsprogs e2fsprogs-resize2fs parted wpa-supplicant util-linux cpufrequtils podman podman-compose "

do_install() {
    # Binaries
    #install -d ${D}${bindir}
    #install -m 0755 ${S}/chronyc ${D}${bindir}
    #install -d ${D}${sbindir}
    #install -m 0755 ${S}/chronyd ${D}${sbindir}

    # Copy general config file
    install -d ${D}${sysconfdir}
    #install -d ${D}${sysconfdir}/composeos
    install -m 644 ${WORKDIR}/composeos.conf ${D}${sysconfdir}/composeos.conf
    
    # Copy library files
    install -d ${D}${base_libdir}
    install -d ${D}${base_libdir}/composeos
    install -m 0644 ${WORKDIR}/base.sh ${D}${base_libdir}/composeos
    install -m 0644 ${WORKDIR}/boot.sh ${D}${base_libdir}/composeos
    install -m 0644 ${WORKDIR}/run.sh  ${D}${base_libdir}/composeos
    install -m 0644 ${WORKDIR}/json.sh ${D}${base_libdir}/composeos
    install -m 0644 ${WORKDIR}/log.sh  ${D}${base_libdir}/composeos
    install -m 0644 ${WORKDIR}/env     ${D}${base_libdir}/composeos
    
    install -m 0755 ${WORKDIR}/bootrc.sh ${D}${base_libdir}/composeos
    install -m 0755 ${WORKDIR}/runrc.sh ${D}${base_libdir}/composeos
    install -m 0755 ${WORKDIR}/net.sh ${D}${base_libdir}/composeos
    install -m 0755 ${WORKDIR}/udhcpc.sh ${D}${base_libdir}/composeos

    # Copy cos utility
    install -d ${D}${bindir}
    install -m 2755 ${WORKDIR}/cos.sh ${D}${bindir}/cos
} 

FILES:${PN} = "${base_libdir}/composeos/* ${sysconfdir}/composeos.conf ${bindir}/cos"
CONFFILES:${PN} = "${sysconfdir}/composeos.conf"

