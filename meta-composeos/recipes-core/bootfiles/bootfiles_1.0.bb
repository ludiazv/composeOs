DESCRIPTION = "copy composeOS config file on boot"
SECTION = "composeOS"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

# Source files to package
SRC_URI += " file://composeos.yml file://cosdbg.yml file://readme.md"

SRC_URI += " \
    file://homer.yml \
    file://portainer.yml \
    file://yacht.yml \
    file://node-red.yml \
"
#file://mosquitto.yml 
INHIBIT_DEFAULT_DEPS = "1"

inherit deploy nopackages

do_deploy() {
    # copy the configuration file
    local src="${@bb.utils.contains('EXTRA_IMAGE_FEATURES','debug-tweaks','cosdbg.yml','composeos.yml',d)}"
    bbnote "COMPOSEOS: Using ${src} <- EXTRA_IMAGE_FEATURES=${EXTRA_IMAGE_FEATURES}" 
    install -m0644 ${WORKDIR}/${src}    ${DEPLOYDIR}/composeos.yml
    #install -m0644 ${WORKDIR}/composeos-dbg.yml ${DEPLOYDIR}/composeos-dbg.yml
    
    # copy builtin examples
    install -d ${DEPLOYDIR}/cos
    install -m0644 ${WORKDIR}/readme.md ${DEPLOYDIR}/cos/.

    local built_in="homer portainer yacht node-red"
    for i in ${built_in}; do
        install -m0644 ${WORKDIR}/${i}.yml ${DEPLOYDIR}/cos/.
    done

    touch ${DEPLOYDIR}/cos/b_date.stamp

}

addtask deploy before do_build after do_install
do_deploy[dirs] += "${DEPLOYDIR}/cos"

PACKAGE_ARCH = "${MACHINE_ARCH}"

