#! /bin/sh

if [ -z $1 ] ; then 
	echo "build folder required" 
	exit 1
fi

echo "bb in $1"
BUILD_CONTAINER=$(yq -r '.crops_container' < composeos.yml)
BOARD=$1

shift

#docker run -ti --rm --name poky -v$(pwd):$(pwd) --workdir=$(pwd) $BUILD_CONTAINER bash -c "source poky/oe-init-build-env build_$BOARD; bitbake --version ; bash"
docker run -ti --rm --name poky -v$HOME/projects:$HOME/projects --workdir=$(pwd) $BUILD_CONTAINER bash -c "source poky/oe-init-build-env build_$BOARD; bitbake --version ; bash"
