
COMPATIBLE_MACHINE = "(sun50i-h616)"
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
SRC_URI:append:orange-pi-zero2 = " file://opizero2-kernel-features.cfg  \
"
# not needed as they were merged in meta-sunxi
#                                   file://0001-Add-usb-support-to-h616.-This-is-not-needed-from-ker.patch \
#                                   file://0001-DTS-orange-pi-zero2-enable-usb.patch \
#"



