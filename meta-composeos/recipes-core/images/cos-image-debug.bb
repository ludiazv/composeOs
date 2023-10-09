SUMMARY = "ComposeOs image (debug)"
DESCRIPTION = "composeOs image with debug tweaks and some extra packages"
LICENSE = "MIT"

require composeos-common.inc 

# Debug features and some extra packages
CORE_IMAGE_EXTRA_INSTALL += " dtc iperf3 hdparm"
EXTRA_IMAGE_FEATURES ?= "debug-tweaks"

# Add activate openrc log
add_open_rc_log() {

    local RC_CONF="${IMAGE_ROOTFS}${sysconfdir}/rc.conf"
    [ -f ${RC_CONF} ] && sed -i 's/^\s*#rc_logger="NO"/rc_logger="YES"/' ${RC_CONF}

}

# Add COS_DEBUG="true" flag
add_cos_debug() {
    local COS_CONF="${IMAGE_ROOTFS}${sysconfdir}/composeos.conf"
    [ -f ${COS_CONF} ] && sed -i 's/COS_DEBUG="false"/COS_DEBUG="true"/' ${COS_CONF}
}

ROOTFS_POSTPROCESS_COMMAND:append = "${@bb.utils.contains('DISTRO_FEATURES','openrc',' add_open_rc_log; add_cos_debug; ','',d)}"

