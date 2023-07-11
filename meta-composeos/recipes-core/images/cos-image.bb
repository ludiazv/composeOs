SUMMARY = "ComposeOs image"
DESCRIPTION = "Include base packages for composeOs with debug tweaks"
LICENSE = "MIT"

require composeos-common.inc 

# include root password

EXTRA_USERS_PARAMS += " \
	usermod -p '${COMPOSEOS_ROOT_PASSWORD}' root; \
"

# Debug features and some extra packages
#CORE_IMAGE_EXTRA_INSTALL += "dtc iperf3 bash"
#EXTRA_IMAGE_FEATURES ?= "debug-tweaks"
