#!/bin/sh
# A minimal simple network configuration tool
# $1 = iface
# $2 = command [up|down]

if [ $# -ne 2 ] ; then
  echo "composeOS net.sh" >&2
  echo "usage: net.sh <iface> [up|down]" >&2
  exit 2
fi

source /lib/composeos/json.sh
source /lib/composeos/log.sh

if=$1
cmd=$2

if [ ! -f "${COS_ETC}/net-${if}.json" ] ; then
  echo "net-$if.json does not exists" >&2
  exit 1
fi

njson=$(cat ${COS_ETC}/net-${if}.json)

cos_get_cnf_val "$njson" ".enabled" "true"
enabled=$__ 
cos_get_cnf_val "$njson" ".type" "wired"
type=$__
cos_get_cnf_val "$njson" ".mode" "dhcp"
mode=$__

cos_echo "composeOS net.sh action required on net interface $if"
cos_echo "  =>info: if=$if cmd=$cmd config=$njson | enabled=$enabled type=$type mode=$mode"

if [ "$enabled" = "false" ]; then
  cos_echo "  => $if is disbled. skipped"
  exit 0
fi


if [ "$cmd" = "up" ]; then
  
  cos_echo "  =>Enabling interface $if"
  # Up the interface
  /sbin/ip link set dev $if up
  cos_echo "  =>Ip up result:'$?'"

  #wifi launch wpa_supplicant
  if [ "$type" = "wpa" -o "$type" = "wifi" ]; then
      mkdir -p ${COS_RUN_DIR}
      echo "ctrl_interface=/var/run/wpa_supplicant_$if" > ${COS_RUN_DIR}/net-wpa_supplicat_$if.conf
      echo "ctrl_interface_group=0" >> ${COS_RUN_DIR}/net-wpa_supplicat_$if.conf
      echo "update_config=1" >> ${COS_RUN_DIR}/net-wpa_supplicat_$if.conf
      cos_get_cnf_val "$njson" ".ssid" "MySSID"
      ssid=$__
      cos_get_cnf_val "$njson" ".psk" ""
      psk=$__
      cos_get_cnf_val "$njson" ".password" ""
      password=$__
      
      echo "network={" >> ${COS_RUN_DIR}/net-wpa_supplicat_$if.conf
      echo "  ssid=\"$ssid\"" >> ${COS_RUN_DIR}/net-wpa_supplicat_$if.conf
      if [ -n "$psk" ]; then
        echo "  psk=$psk" >> ${COS_RUN_DIR}/net-wpa_supplicat_$if.conf
      else 
        if [ -n "$password" ]; then
           echo "  psk=\"$password\"" >> ${COS_RUN_DIR}/net-wpa_supplicat_$if.conf  
        else
           echo "  key_mgmt=NONE" >> ${COS_RUN_DIR}/net-wpa_supplicat_$if.conf
        fi
      fi
      echo "}" >> ${COS_RUN_DIR}/net-wpa_supplicat_$if.conf
      cos_echo "  =>Created wpa_supplicat configuration for $if in file ${COS_RUN_DIR}/net-wpa_supplicat_$if.conf:"
      cos_echo "$(cat ${COS_RUN_DIR}/net-wpa_supplicat_$if.conf)"
      
      # runing wpa_supplicat
      /usr/sbin/wpa_supplicant -c ${COS_RUN_DIR}/net-wpa_supplicat_$if.conf -B -i $if -P ${COS_RUN_DIR}/wpa-$if.pid
      cos_echo "  => wpa_supplicant result: '$?'"
  fi
      
  # DHCP mode or static
  if [ "$mode" = "dhcp" ]; then
    /sbin/udhcpc -b -i $if -p ${COS_RUN_DIR}/udhcpc-$if.pid -s /lib/composeos/udhcpc.sh
    cos_echo "  => dhcpc result: '$?'"
  else
   cos_get_cnf_val "$njson" ".address" "192.168.1.10"
   addr=$__
   cos_get_cnf_val "$njson" ".netmask" "255.255.255.0"
   netmask=$__
   cos_get_cnf_val "$njson" ".gateway" "192.168.1.1"
   gateway=$__
   
   metric=10
   cos_echo "  =>static configuration address=$addr netmask=$netmask gateway=$gateway metric=$metric"
   /sbin/ip addr add dev $if local $addr/$netmask broadcast + 
   ra=$?
   /sbin/ip route add default via $gateway metric $metric dev $if
   cos_echo "  =>ip addr result='$ra' | ip route result='$?'"
  fi
  
  cos_echo "composeOS net.sh UP finished."
  exit 0
fi

if [ "$cmd" = "down" ]; then
  
  cos_echo "  =>Disabling network interface $if"

  if [ -f ${COS_RUN_DIR}/udhcpc-$if.pid ] ; then
    cos_echo " => Killing udhcpc client for $if with pid $(cat ${COS_RUN_DIR}/udhcpc-$if.pid)"
    kill -USR2 $(cat ${COS_RUN_DIR}/udhcpc-$if.pid)
    kill -SIGTERM $(cat ${COS_RUN_DIR}/udhcpc-$if.pid)
  fi

  if [ -f ${COS_RUN_DIR}/wpa-$if.pid ] ; then
    cos_echo "  => Killing wpa_supplicant for $if with pid $(cat ${COS_RUN_DIR}/wpa-$if.pid)"
    kill -SIGTERM $(cat ${COS_RUN_DIR}/wpa-$if.pid)
  fi
  
  cos_echo "  => Remove routes, addresses and setting down interface $if"
  /sbin/ip -4 addr flush dev $if
  /sbin/ip route flush dev $if
  /sbin/ip link set $if down
  
  cos_echo "composeOS net.sh DOWN finished."
  exit 0
fi

# error exit
echo "composeOS net.sh UNK command $cmd" >&2
exit 1
