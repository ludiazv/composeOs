#!/bin/bash

### BEGIN INIT INFO
# Provides:          composeos
# Required-Start:
# Required-Stop:
# Default-Start:     S
# Default-Stop:
# Short-Description: Startup script for composeOS
### END INIT INFOi
#

#
# ComposeOs init script
#
#set -x

# include composeos boot library
source /lib/composeos/boot.sh

if [ "$1" = "start" ] ; then
  
  echo "Init composeOS start"
  cos_generate_conf_file_md5
  echo "Init composeOS start finished"
fi # Start

exit 0



