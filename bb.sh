#! /bin/sh

if [ -z $1 ] ; then 
	echo "build folder required" 
	exit 1
fi

echo "bb in $1"
BUILD_CONTAINER=$(yq '.crops_container' < project.yml)
BOARD=$1

shift

docker run -t --rm --name bb -v$(pwd):$(pwd) --workdir=$(pwd) $BUILD_CONTAINER bash -c "source poky/oe-init-build-env $BOARD; bitbake $@"
