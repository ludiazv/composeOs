SUMMARY = "ComposeOs image (debug)"
DESCRIPTION = "Include base packages for composeOs with debug tweaks"
LICENSE = "MIT"

require composeos-common.inc 

# Debug features and some extra packages
CORE_IMAGE_EXTRA_INSTALL += " dtc iperf3 "
EXTRA_IMAGE_FEATURES ?= "debug-tweaks"

# Add activate openrc log
add_open_rc_log() {

    local RC_CONF="${IMAGE_ROOTFS}${sysconfdir}/rc.conf"
    [ -f ${RC_CONF} ] && sed -i 's/^\s*#rc_logger="NO"/rc_logger="YES"/' ${RC_CONF}

}

ROOTFS_POSTPROCESS_COMMAND:append = "${@bb.utils.contains('DISTRO_FEATURES','openrc',' add_open_rc_log;','',d)}"

