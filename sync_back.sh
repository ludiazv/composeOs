#!/bin/bash
#
#
# sshfs root@192.168.50.46:/ mnt

echo "sync back lib+env"
cp -v mnt/lib/composeos/*.sh meta-composeos/recipes-core/composeoslib/files/.
cp -v mnt/lib/composeos/env meta-composeos/recipes-core/composeoslib/files/.
echo "sync back etc"
cp -v mnt/etc/composeos.conf meta-composeos/recipes-core/composeoslib/files/.
echo "sync boot"
cp -v mnt/boot/composeos.yml meta-composeos/recipes-core/bootfiles/files/cosdbg.yml
echo "cos utility"
cp -v mnt/usr/bin/cos meta-composeos/recipes-core/composeoslib/files/cos.sh


echo "done!"
