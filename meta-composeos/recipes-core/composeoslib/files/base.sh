source /lib/composeos/json.sh
source /lib/composeos/log.sh

# Config file functions
# .....................

cos_generate_conf_file_md5() {
  md5sum  $COS_CONF_FILE > $COS_CONF_FILE_MD5
}

# utils
# ------
trim() {
  echo "$1" | xargs
}

# get abs path from relative entry
get_path() {
  local p=$1
  local r=$2

  if [ -z $p ] ; then
    __=""
    return 0
  fi

  if [ "$p" != "$(realpath $p)" ] ; then # relative path
      __=$r/$p
  else
     __=$p
  fi
  
  return 0
}

# Configuration manipulation functions
# ------------------------------------

cos_load_cnf() {
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

# finds root partions
# returns 0 on succhess 1 if not found
# __ = rotfs particion info informat "diskid:disk_name:part_order:part_name"
find_rootfs() {
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
        j=$((j+1))
    done
    cos_echo "<"
    i=$((i+1))
  done
  __=""
  return 1

}

set_timezone() {
  local tz=$1
  local tz_path="/usr/share/zoneinfo/$tz"
  
  cos_printf " >Setting up timezone to $tz ..."
  if [ ! -f $tz_path ] ; then
    cos_printf " $tz_path does not exists falling back to Universal ..."
    tz="Universal"
    tz_path="/usr/share/zoneinfo/$tz"
  fi

  if [ -L /etc/localtime ]; then
    local lk=$(readlink /etc/localtime)
    if [ "$tz_path" = "$lk" ]; then
      cos_echo " /etc/localtime is already pointing to $tz_path. nothing to do. <"
    else
      rm -f /etc/localtime
      ln -s $tz_path /etc/localtime
      cos_echo " change localtime from $lk to $tz_path. <"
    fi
  else
    cos_echo "creating /etc/localtime -> $tz_path .<"
    ln -s $tz_path /etc/localtime
  fi
  __=$tz
  return 0
}

# Swap helper function
activate_swap() {
  local swap_path=$1
  local zswap=$2
  local zswap_algo=$3
  local zswap_pool=$4
  

  cat /proc/swaps > /run/swp.txt
  if grep -q "$swap_path" /run/swp.txt ; then
    cos_echo " >Swap file $swap_path is aleady activated <"
    return 0
  fi

  cos_printf " >Activate swap space with [path=$swap_path zswap=$zswap zswap_algo=$zswap_algo zswap_pool=$zswap_pool] ..."
  if [ -f $swap_path ] ; then
      if swapon $swap_path ; then
          cos_printf "swap file activated $swap_path "
          if [ $zswap -gt 0 ] ; then
            if [ -d /sys/module/zswap/parameters ]; then
              echo $zswap > /sys/module/zswap/parameters/max_pool_percent
              echo $zswap_algo > /sys/module/zswap/parameters/compressor
              echo $zswap_pool > /sys/module/zswap/parameters/zpool
              echo 1 > /sys/module/zswap/parameters/enabled
              cos_printf " .. ZSWAP enabled"
            else
              cos_printf " .. ZSWAP is not enabled in kernel /sys/module/zswap/parameters does not exists"
            fi
          else
            echo 0 > /sys/module/zswap/parameters/enabled
            cos_printf " .. ZSWAP disabled"
          fi
      else
        cos_printf "SWAPON failed on $swap_path"
      fi
      cos_echo " <"
  else
    cos_echo "$swap_path does not exists. No swap will be activated <"
  fi
  return 0
}

create_swap_file() {
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
# $1 = ifaces array
# $2 = index of the interface you need
# $3 = dns space seprated list
# $4 = domain string
add_network_ifup_iface() {
    local njson=$1
    local i=$2
    local dns=$3
    local domain=$4
    
    cos_get_cnf_val "$njson" ".[${i}].enabled" "true"
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
      cos_get_cnf_val "$njson" ".[$i].address" "192.168.1.10"
      local addr=$__
      cos_get_cnf_val "$njson" ".[$i].netmask" "255.255.255.0"
      local netmask=$__
      cos_get_cnf_val "$njson" ".[$i].gateway" "192.168.1.1"
      local gateway=$__
      echo "   address $addr" >> /etc/network/interfaces
      echo "   netmask $netmask" >> /etc/network/interfaces
      echo "   gateway $gateway" >> /etc/network/interfaces
    fi # static

    if [ ! -z "$dns" ] ; then
     #cos_get_cnf_arr "$dns" "." "$COS_DEFAULT_DNS"
     #local nsl=$__
     echo "   dns-nameservers $dns" >> /etc/network/interfaces
    fi

    if [ ! -z "$domain" ] ; then
       echo "   dns-search $dns" >> /etc/network/interfaces 
    fi
    

    if [ "$type" = "wifi" -o "$type" = "wpa" ] ; then
      cos_get_cnf_val "$njson" ".[$i].ssid" "MySSID"
      local ssid=$__
      cos_get_cnf_val "$njson" ".[$i].psk" "mypsk"
      local psk=$__
      echo "   wpa-ssid \"$ssid\"" >> /etc/network/interfaces

      cos_cnf_has_key "$njson" ".[$i].password"
      if [ $? -eq 0 ] ; then
          cos_get_cnf_val "$njson" ".[$i].password" "mypass"
          echo "   wpa-psk  \"$__\""   >> /etc/network/interfaces
      else
          echo "   wpa-psk  \"$psk\""  >> /etc/network/interfaces
      fi
    fi # wifi
        
    echo "# ComposeOS iface $i $iface end" >> /etc/network/interfaces
    echo "" >>/etc/network/interfaces
    cos_echo " done! <"
}

# mount helper
mount_dev() {
  local mjson=$1
  local i=$2

  cos_get_cnf_val "$mjson" ".[$i].dev" "/dev/sda1"
  local dev=$__
  cos_get_cnf_val "$mjson" ".[$i].name" "data"
  local mp="/mnt/$__"
  cos_get_cnf_val "$mjson" ".[$i].type" "ext4"
  local type=$__
  cos_get_cnf_val "$mjson" ".[$i].options" "defaults"
  local opts=$__
  cos_get_cnf_val "$mjson" ".[$i].root" "false"
  local for_root=$__
  cos_get_cnf_val "$mjson" ".[$i].main_storage" "false"
  local is_main_storage=$__

  cos_printf " >mount $dev on $mp type=$type , opts=$opts , as root=$for_root , is_main_storage=$is_main_storage ..."
  if mount | grep $dev > /dev/null ; then
    cos_echo " $dev is already mounted. not applied <"
    return 0
  fi
  if mount | grep $mp > /dev/null ; then
    cos_echo " $mp is already mounted. not applied <"
    return 0
  fi
  mkdir -p $mp
  if mount $dev -t $type -o $opts $mp &> /dev/null ; then
    cos_printf "mounted OK ..."
    local mpu="composeos"
    if [ "$for_root" = "true" ]; then
      mpu="root"
    fi
    chown $mpu:$mpu $mp
    cos_echo "for user $mpu res:$?. <"
    if [ "$is_main_storage" = "true" ]; then
      cos_echo " > Setting COS_MAINSTORAGE to $mp . <"
      COS_MAINSTORAGE=$mp
    fi
  else
    cos_echo " mount FAILED with result: '$?'. <"
  fi
  return 0

}

# custom script runner
cos_run_script() {
    local name=$1
    local script=$2
    local user=$3

    # prepare the file
    local srcf="${COS_RUN_DIR}/${name}.sh"
    echo "#!/bin/sh" > $srcf
    echo "# generated script by compose os with name=${name}" >> $srcf
    echo "[ -f ${COS_ENV_FILE} ] && source ${COS_ENV_FILE}"
    echo "$script" >> $srcf
    echo "exit 0"  >> $srcf
    chmod +x $srcf
    chown $user:$user $srcf

    cos_printf " => Running script '$name' [$srcf] as '$user' ..."
    if su -l -c "$srcf" $user ; then
      cos_echo "result:'$?' OK"
    else
      cos_echo " FAILED with result='$?'"
    fi
    #rm /run/${name}.sh
    return 0
}

# populate functions
cos_populate_own_perms() {
  local path=$1
  local usr=$2
  local perms=$3
  
  # check user and change if required
  local curr_usr=$(stat -c "%U" $path)
  if [ "$usr" != "$curr_usr" ] ; then
    chown $usr:$usr $path
    cos_printf "[change file ownership from $curr_usr -> $usr]"
  else
    cos_printf "[owned by '$usr']"
  fi

  # check permisssions
  local curr_perm=$(stat -c "%a" $path)
  if [ "$perms" != "$curr_perm" ] ; then
    chmod $perms $path
    cos_printf "[change file perms from $curr_perm -> $perms]"
  else
    cos_printf "[perms '$perms']"
  fi

}


cos_populate_file() {
  local file=$1
  local usr=$2
  local force=$3
  local perms=$4
  local content=$5

  
  cos_printf "[file:$file]"
  local dir=$(dirname $file)

  # Be sure directory exists
  if [ ! -d $dir ] ; then
    mkdir -p $dir
    cos_printf "[created directory:'$dir']"
  fi

  # Create the file with content
  if [ ! -f $file -o "$force" = "true" ] ; then
    touch $file
    [ ! -z "$content" ] && echo -n "$content" > $file
    cos_printf "[created/overwritten '$file']"
  else
    cos_printf "[file present and not forced]"
  fi


  [ -z "$perms" ] && perms=${COS_DEFAULT_FILEPERMS}
  cos_populate_own_perms "$file" "$usr" "$perms"

  cos_printf "[$file size:$(stat -c '%s' $file) b]"

}

cos_populate_dir() {
  local dir=$1
  local usr=$2
  local perms=$4

  cos_printf "[dir:$dir]"

  if [ ! -d $dir ] ; then
    mkdir -p $dir
    cos_printf "[created directory '$dir']"
  else
    cos_printf "[directory exits]"
  fi

  [ -z "$perms" ] && perms=${COS_DEFAULT_DIRPERMS}
  cos_populate_own_perms "$dir" "$usr" "$perms"

}


cos_populate_element() {
  local el=$1
  local base=$2
  local usr="${COS_USER}"
  
  cos_get_cnf_val "$el" ".file" ""
  local file=$__
  get_path "$file" "$base"
  file=$__
  cos_get_cnf_val "$el"  ".dir"  ""
  local dir=$__
  get_path "$dir" "$base"
  dir=$__
  cos_get_cnf_val "$el" ".content" ""
  local content=$__
  cos_get_cnf_val "$el" ".force" "false"
  local force=$__
  cos_get_cnf_val "$el" ".root" "false"
  local as_root=$__
  cos_get_cnf_val "$el" ".perms" ""
  local perms=$__

  [ "$as_root" = "true" ] && usr="root"
  
  cos_printf "  => [force: '$force' / as_root: '$as_root' / perms: '$perms'] "
  if [ -z $dir -a -z $file ] ; then
     cos_echo " no 'dir' or 'file' keys defined. nothing to do <="
     return 0
  fi
  [ -z $dir -a ! -z $file ]    && cos_populate_file "$file" "$usr" "$force" "$perms" "$content"
  [ ! -z $dir -a -z $file ]    && cos_populate_dir  "$file" "$usr" "$perms"
  [ ! -z $dir -a ! -z $file ]  && cos_populate_file "$file" "$usr" "$force" "$perms" "$content"

  cos_echo " <="
  return 0
}

cos_populate() {
  local pop_arr=$1
  local base_dir=$2
  local usr="${COS_USER}"

  cos_get_cnf_arr_len "$pop_arr" "."
  local len=$__
  cos_echo "[POPULATE] Populating #$len entries with base dir='$base_dir'..."

  len=$((len-1))
  for i in $(seq 0 $len); do
     cos_get_cnf_obj "$pop_arr" ".[$i]" ""
     [ ! -z $__ ] && cos_populate_element "$__" "$base_dir" "$usr"
  done

  cos_echo "[POPULATE] finished."


}


# vim: set ft=sh
