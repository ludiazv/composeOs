SUMMARY = "ComposeOs image"
DESCRIPTION = "composeOs imange for release"
LICENSE = "MIT"

require composeos-common.inc 

# include root password

EXTRA_USERS_PARAMS += " \
	usermod -p '${COMPOSEOS_ROOT_PASSWORD}' root; \
"

