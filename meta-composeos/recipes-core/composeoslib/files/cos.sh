#!/bin/sh
# composeOs up-down utility
# $1 = [up|down]
# $* = list of stacks to up down if empty all enabled stacks will affected

# preamble
PODC="/usr/bin/podman-compose"
source /etc/composeos.conf



if [ ! -f ${COS_ENV_FILE} ] ; then
  echo "no ${COS_ENV_FILE}. aborting" >&2
  exit 1
fi

source ${COS_ENV_FILE}

# do stack function
# $1 cmd
# $2 stack_name
do_stack() {
  local c=$1
  local sn=$2

  local cmd_pars="up -d --no-color"

  [ "$c" != "up" ] && cmd_pars="down"

  local usr="composeos"
  local env_file="--env-file ${COS_ENV_FILE}"
  local enabled="true"

  [ ! -f "${COS_RUN_DIR}/cs-${sn}.yml" ] && return 1
  [ -f "${COS_RUN_DIR}/cs-${sn}.usr" ] && usr=$(cat ${COS_RUN_DIR}/cs-$sn.usr)
  [ -f "${COS_RUN_DIR}/cs-${sn}.env" ] && env_file="--env-file ${COS_RUN_DIR}/cs-${sn}.env"
  [ -f "${COS_RUN_DIR}/cs-${sn}.enabled" ] && enabled=$(cat ${COS_RUN_DIR}/cs-$sn.enabled)

  # run the command
  if [ "$enabled" = "true" ] ; then
    echo "UP[$sn, usr=$usr, env=$env_file, cmd=$cmd_pars]" 
    su -l -c "$PODC -f ${COS_RUN_DIR}/cs-${sn}.yml ${env_file} $cmd_pars" $usr
    return $?
  else
    printf " '$sn' is disabled. skipping "
  fi
  return 0
}

do_list() {

  echo "Listing stacks..."
  
  for s in $(ls -1 ${COS_RUN_DIR}/*.yml) ; do
    local sp=${s%.yml}
    local sn=${sp#cs\-}
    printf "- [$sp]: yml[ok] "
    [ -f $sp.env ] && printf "env[ok] "
    [ -f $sp.usr ] && printf "usr[ok] "
    [ -f $sp.enabled ] && printf "enabled[$(cat $sp.enabled)]"
    echo ""
  done

  [ -f ${COS_RUN_DIR}/enabled ] && echo "Enabled list:$(cat ${COS_RUN_DIR}/enabled)"

}

# usage
if [ $# -lt 1 ] ; then
  echo "composeOS stack compose utility" >&2
  echo "usage: net.sh <up|down|list> [..list of stacks..]" >&2
  exit 2
fi


# check supported commands
if [ "$1" = "up" -o "$1" = "down" -o "$1" = "list" ] ; then
  cmd="$1"
  shift
else
  echo "invalid command '$1'" >&2
  exit 1
fi

# get desired stacks
stacks="$*"
[ $# -eq 0 -a -f ${COS_RUN_DIR}/enabled ] && stacks=$(cat ${COS_RUN_DIR}/enabled)

if [ "$cmd" = "list" ] ; then
  do_list
  exit 0
fi

if [ -z "${stacks}" ] ; then
  echo "no stacks are available" >&2
  exit 1
fi


# Up & down commands
for s in $stacks ; do
  if [ ! -f "${COS_RUN_DIR}/cs-$s.yml" ] ; then
    echo " cs-$s.yml not found. skipping"
    continue
  fi
  printf "Runing '$cmd' for stack '$s'..."
  if do_stack "$cmd" "$s" ; then
    echo "OK."
  else
    echo "FAILED."
  fi
done

exit 0



