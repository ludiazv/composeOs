# composeOS library file
# to be sourced in bash script
#
# General variables
COS_BOOTLOG_FILE="/boot/cosboot.log"
COS_CONF_FILE="/boot/composeos.yml"
COS_CONF_FILE_MD5="/boot/composeos.md5"

COS_DEFAULT_TIMESERVERS="0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org"
COS_DEFAULT_IFACES='[{"type":"wired","iface":"eth0","enabled":true,"mode":"dhcp"}]'
COS_DEFAULT_DNS="9.9.9.9 1.1.1.1"
COS_DEFAULT_MOUNT="[]"


COS_DEBUG="false"


# Log functions
# --------------
function init_cos_boot_log() {
  echo "composeOS boot log init" >  $COS_BOOTLOG_FILE
  #echo "composeOS boot log initialized"
  return 0
}

function cos_printf() {
  local out="$*"
  [ "$COS_DEBUG" = "true" ] && printf "$out"
  printf "$out" >> $COS_BOOTLOG_FILE
}

function cos_echo() {
  local out="$*"
  [ "$COS_DEBUG" = "true" ] && echo "$out"
  echo "$out" >> $COS_BOOTLOG_FILE
}


# Config file functions
# .....................

function cos_generate_conf_file_md5() {
  md5sum  $COS_CONF_FILE > $COS_CONF_FILE_MD5
}

# utils
# ------
function trim() {
    local trimmed="$1"

    # Strip leading spaces.
    while [[ $trimmed == ' '* ]]; do
       trimmed="${trimmed## }"
    done
    # Strip trailing spaces.
    while [[ $trimmed == *' ' ]]; do
        trimmed="${trimmed%% }"
    done

    echo "$trimmed"
}


# Configuration manipulation functions
# ------------------------------------

function cos_load_cnf() {
  #local fcnf=$(yq r -j $COS_CONF_FILE)
  local fcnf=$(dasel -f $COS_CONF_FILE -r yaml -w json)
  cos_echo "Full configuration loaded => $fcnf"
  if [ "$(echo $fcnf | jq 'has("start")')" = "true" ] ; then
    cos_cnf_start=$(echo $fcnf | jq -cM '.start')
    cos_echo "Loaded config for start => $cos_cnf_start"
    if [ "$(echo $fcnf | jq 'has("compose")')" = "true" ] ; then
      cos_cnf_compose=$(echo $fcnf | jq -cM '.compose')
      cos_echo "Loaded config for compose => $cos_cnf_compose"
      return 0
    fi
  fi
  return 1
}

function cos_get_cnf_val() {
   local json=$1
   local cnf_var=$2
   local cnf_def=$3
   local t=$(echo $json | jq -r "$cnf_var")
   if [ "$t" = "null" ] ; then
      __=$3
   else
      __=$t
   fi
   return 0
}

function cos_get_cnf_arr() {
  local json=$1
  local cnf_var=$2
  local cnf_def=$3
  local t=$(echo $json | jq -cM "$cnf_var")
  if [ "$t" = "null" ] ; then
    __=$cnf_def
  else
    __=$(echo $json | jq -r "$cnf_var[]")
  fi
  return 0
}

function cos_get_cnf_arr_len() {
  local json=$1
  local cnf_var=$2
  local t=$(echo $json | jq -cM "$cnf_var")
  if [ "$t" = "null" ] ; then
    __=0
  else
    __=$(echo $json | jq -r "$cnf_var | length")
  fi
  return 0
}

function cos_get_cnf_obj() {
  local json=$1
  local cnf_var=$2
  local cnf_def=$3
  local t=$(echo $json | jq -cM "$cnf_var")
  
  if [ "$t" = "null" ] ; then
    __=$3
  else
    __=$t
  fi

  return 0
}



# finds root partions
# returns 0 on succhess 1 if not found
# __ = rotfs particion info informat "diskid:disk_name:part_order:part_name"
function find_rootfs() {
  local bdevices=$(lsblk -J -o NAME | jq -r '.blockdevices[].name')

  local i=0
  for bd in $bdevices ; do
    cos_printf ">Checking block device $i:$bd..."

    local j=0
    local parts=$(lsblk -J -o NAME | jq -r ".blockdevices[$i].children[].name")
    for p in $parts ; do
        local mountp=$(lsblk -J -o NAME,MOUNTPOINT | jq -r ".blockdevices[$i].children[$j].mountpoint")
        local size=$(lsblk -J -o NAME,SIZE | jq -r ".blockdevices[$i].children[$j].size")
        cos_printf "[$j:$p mounted:$mountp size:$size]=>"
        if [ "$mountp" = "/" ] ; then
           cos_echo "ROOTFS <"
           __="$i:$bd:$j:$p"
           return 0
        fi
        cos_printf "NOROOTFS .. "
        ((j=j+1))
    done
    cos_echo "<"
    ((i=i+1))
  done
  __=""
  return 1

}

# Swap helper function
function activate_swap() {
  local swap_path=$1
  local zswap=$2
  local zswap_algo=$3
  local zswap_pool=$4

  swapon | grep "$swap_path" >/dev/null
  if [ $? -eq 0 ] ; then
    cos_echo " >Swap file $swap_path is aleady activated <"
    return 0
  fi
  
  cos_printf " >Activate swap space with [path=$swap_path zswap=$zswap zswap_algo=$zswap_algo zswap_pool=$zswap_pool] ..."
  if [ -f $swqp_path ] ; then
    local swr=$(swapon $swap_path)
      if [ $? -eq 0 ] ; then
          cos_printf "swap file ON"
          if [ $zswap -gt 0 ] ; then
            echo $zswap > /sys/module/zswap/parameters/max_pool_percent
            echo $zswap_algo > /sys/module/zswap/parameters/compressor
            echo $zswap_pool > /sys/module/zswap/parameters/zpool
            echo 1 > /sys/module/zswap/parameters/enabled
            cos_printf " .. ZSWAP enabled"
          else
            echo 0 > /sys/module/zswap/parameters/enabled
            cos_printf " .. ZSWAP disabled"
          fi
      fi
      cos_echo " <"
      cos_echo "$swr"
  else
    cos_echo "$swap_path does not exists. No swap will be activated <"
  fi
  return 0
}

function create_swap_file() {
   local swap_path=$1
   local swap_size=$2
  
   cos_printf " >Create swap file $swap_path with $swap_size MiB... "
   [ -f $swap_path ] && rm $swap_path && cos_printf "removed existing $swap_path"
   #swap_size=(( $swap_size * 1024 * 1024 ))
   local ddr=$(dd if=/dev/zero of=$swap_path bs=1M count=$swap_size )
   sync
   chmod 600 $swap_path
   local mkr=$(mkswap $swap_path)

   cos_echo " Done <"
   cos_echo "$ddr"
   cos_echo "$mkr"

   return 0
}

# Network helper functions
function add_network_iface() {
    local njson=$1
    local i=$2
    cos_get_cnf_val "$njson" ".[${i}].enabled" "false"
    local enabled=$__ 
    cos_get_cnf_val "$njson" ".[$i].type" "wired"
    local type=$__
    cos_get_cnf_val "$njson" ".[$i].mode" "dhcp"
    local mode=$__
    cos_get_cnf_val "$njson" ".[$i].iface" "eth0"
    local iface=$__

    cos_printf " > Adding network configuration $i $iface ..."
    echo "# ComposeOs iface [$i] $iface => enabled:$enabled, type: $type, mode: $mode, " >> /etc/network/interfaces
    [ ! "$enabled" = "false" ] && echo "auto $iface" >> /etc/network/interfaces
    printf "iface $iface inet " >> /etc/network/interfaces
    if [ ! "$mode" = "static" ] ; then
      echo "dhcp" >> /etc/network/interfaces
    else
      echo "static" >> /etc/network/interfaces
      cos_get_cnf_val "$njson" ".[$i].static.address" "192.168.1.10"
      local addr=$__
      cos_get_cnf_val "$njson" ".[$i].static.netmask" "255.255.255.0"
      local netmask=$__
      cos_get_cnf_val "$njson" ".[$i].static.gateway" "192.168.1.1"
      local gateway=$__
      echo "   address $addr" >> /etc/network/interfaces
      echo "   netmask $netmask" >> /etc/network/interfaces
      echo "   gateway $gateway" >> /etc/network/interfaces
      
      cos_get_cnf_arr "$njson" ".[$i].dns" "$COS_DEFAULT_DNS"
      local nsl=$__
      echo "   dns-nameservers $ns" >> /etc/network/interfaces

      if [ "$type" = "wifi" -o "$type" = "wpa" ] ; then
        cos_get_cnf_val "$njson" ".[$i].ssid" "MySSID"
        local ssid=$__
        cos_get_cnf_val "$njson" ".[$i].psk" "mypsk"
        local psk=$__
        echo "   wpa-ssid \"$ssid\"" >> /etc/network/interfaces
        echo "   wpa-psk  \"$psk\""  >> /etc/network/interfaces

      fi
      
    fi
    echo "# ComposeOS iface $i $iface end" >> /etc/network/interfaces
    echo "" >>/etc/network/interfaces
    cos_echo " done! <"
    

}

# mount helper
function mount_dev() {
  local mjson=$1
  local i=$2

  cos_get_cnf_val "$mjson" ".[$i].dev" "/dev/sda1"
  local dev=$__
  cos_get_cnf_val "$mjson" ".[$i].mount_point" "/mnt/data"
  local mp=$__
  cos_get_cnf_val "$mjson" ".[$i].type" "ext4"
  local type=$__
  cos_get_cnf_val "$mjson" ".[$i].options" "defaults"
  local opts=$__

  cos_printf " >mount $dev on $mp type=$type , opts=$opts ..."
  mount | grep $dev > /dev/null
  if [ $? -eq 0 ] ; then
    cos_echo " $dev is already mounted. <"
    return 0
  fi
  mount | grep $mp > /dev/null
  if [ $? -eq 0 ] ; then
    cos_echo " $mp is already mounted. <"
    return 0
  fi
  mount $dev -t $type -o $opts $mp
  local res=$?
  cos_echo " mount result: '$res'. <"
  return $res

}


