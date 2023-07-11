# Common image defition for composeOS images
inherit core-image openrc-image extrausers


# General image config
IMAGE_LINGUAS = " "
IMAGE_ROOTFS_SIZE ?= "8192"

IMAGE_INSTALL = "${@bb.utils.contains('DISTRO_FEATURES', 'openrc', 'openrc', '', d)}"
IMAGE_INSTALL += "packagegroup-core-boot ${CORE_IMAGE_EXTRA_INSTALL}"

# Define enabled & disabled services
OPENRC_SERVICES += " \
    sysinit:udev-trigger \
    default:udev-settle \
    boot:composeos-boot \
    default:composeos-run \
    boot:chronyd \
    default:chrony-wait \
"
OPENRC_DISABLED_SERVICES = " \
    boot:swap \
"


# Add configuration file and templates
IMAGE_BOOT_FILES:append = " composeos.yml cos/*;cos/"

# User setup
# hashes are create with this command in host printf "%q" $(mkpasswd -m sha256crypt <pwd>)
COMPOSEOS_ROOT_PASSWORD = "\$5\$.G2iFTf/rozBeSYI\$.Gxokp1fjucEbnJ79B/qwzdAkVal9B7c9SbkMzyPWR2"
COMPOSEOS_PASSWORD= "\$5\$xaxjZArFuSDbryto\$3mnmqA/wayL/AEWzw7TBYJ7MLJUIolBos30Dw6sMeX/"
EXTRA_USERS_PARAMS += " \
	groupadd -g 1000 composeos; \
	useradd -u 1000 -p '${COMPOSEOS_PASSWORD}' -s /bin/sh -g 1000 composeos; \
"

# Needed system software
# Support for kernel modules and mod tools and cgroups support required for contariners
CORE_IMAGE_EXTRA_INSTALL += "kernel-modules kmod cgroup-lite"
# Date and time 
CORE_IMAGE_EXTRA_INSTALL += "tzdata chrony"
# Container utils. (py modules are required by podman-copose)
CORE_IMAGE_EXTRA_INSTALL += " podman-tui "
#python3-json python3-dotenv python3-logging "
# Extra fundamental tools
CORE_IMAGE_EXTRA_INSTALL += "htop nano"

# Custom packages (in this layer)
CORE_IMAGE_EXTRA_INSTALL += "${@bb.utils.contains('DISTRO_FEATURES', 'openrc', 'composeos-openrc', 'composeos-init', d)}"


IMAGE_FEATURES += "ssh-server-dropbear"

# force bootfiles deploy before wic
#do_image_wic[dependpkgs] += " bootfiles:do_deploy "
do_image_wic[depends] += " bootfiles:do_deploy "

