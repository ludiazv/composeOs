# composeos functions for boot
source /lib/composeos/base.sh

# mount desired fs
# $1 json of mount section
cos_do_mount() {
  local cos_cnf_mount=$1

  cos_get_cnf_arr_len "$cos_cnf_mount" "."
  local mount_len=$__
  cos_echo "[mount] Mounting required #${mount_len} filesystems..."
  mount_len=$((mount_len-1))
  local i
  for i in $(seq 0 $mount_len) ; do
      mount_dev "$cos_cnf_mount" $i
  done
  cos_echo "[mount] finished."

}

cos_do_resize() {

  find_rootfs
  local rootfs=$__
  cos_echo "[resize] resize root fs..."
  local root_disk="/dev/$(echo $rootfs | cut -d ':' -f 2)"
  local root_part="/dev/$(echo $rootfs | cut -d ':' -f 4)"
  local root_part_index=$(echo $rootfs | cut -d ':' -f 3)
  cos_echo "current root disk '$root_disk' status:"
  cos_echo "$(parted -s $root_disk 'print free')"

  # Get disk info

  local max_first_sector= sector_size= disk_last_sector= root_part_number= root_first_sector= root_last_sector=
  # Version with parted json
  local t=$(parted -j -s $root_disk 'unit s print')
  sector_size=$(echo $t | jq -r '.disk."logical-sector-size"')
  root_first_sector=$(echo $t | jq -r ".disk.partitions[$root_part_index].start" | jq -rR 'gsub("s";"")')
  root_last_sector=$(echo $t | jq -r ".disk.partitions[$root_part_index].end" | jq -rR 'gsub("s";"")')
  root_part_number=$(echo $t | jq -r ".disk.partitions[$root_part_index].number")
  max_first_sector=$(echo $t | jq -cM '[ .disk.partitions[].start | gsub("s";"") | tonumber ]' | jq -r 'max') 
  disk_last_sector=$(echo $t | jq -r ' (.disk.size | gsub("s";"") | tonumber) - 1') 

  # Version with parted machine output to be used json vestion on new version of yocto with more recent parted
  #local OLD_IFS=$IFS
  #local h=
  #parted -m -s $root_disk 'unit s print' | awk -F ';' '{i=1; while(i<NF) { print $i; i++}}'  > /run/part.txt
  #while IFS= read -r line; do
  #  h=$(echo $line | cut -d ':' -f 1)
  #  if [ "$h" = "BYT" ] ; then
  #     continue
  #  fi
  #  if [ "$h" = "$root_disk" ] ; then
  #      sector_size=$(echo $line | cut -d ':' -f 4)
  #      disk_last_sector=$(echo $line | cut -d ':' -f 2)
  #      disk_last_sector=${disk_last_sector%s}
  #      disk_last_sector=$(($disk_last_sector - 1))
  #      continue
  #  fi
  #  if echo $h | egrep -q '^[0-9]+$' ; then
  #     local pn=$(echo $line | cut -d ':' -f 1)
  #     max_first_sector=$(echo $line | cut -d ':' -f 2)
  #     max_first_sector=${max_first_sector%s}
  #     if [ $((root_part_index + 1 )) -eq $pn ] ; then
  #      root_part_number=$pn
  #      root_first_sector=$max_first_secto:E..r
  #      root_last_sector=$(echo $line | cut -d ':' -f '3')
  #      root_last_sector=${root_last_sector%s}
  #     fi
  #  fi
  #done < /run/part.txt
  #rm -f /run/part.txt
  #IFS=$OLD_IFS

  # Show info
  cos_echo "DISK INFO=>root disk: $root_disk | sector size: $sector_size | last disk sector: $disk_last_sector | last partition start: $max_first_sector"
  cos_echo "ROOT PART=>root part: $root_part | part index: $root_part_index | parted number: $root_part_number | first sector: $root_first_sector | last sector: $root_last_sector"
      
  if [ $max_first_sector -eq $root_first_sector ] ; then

    cos_echo "rootfs $root_part is the last partion starting at $max_first_sector"
    local free_space=$(( $disk_last_sector - $root_last_sector ))
    cos_echo "Free space to resize $free_space sectors [ $(( $free_space * $sector_size / 1000000 )) MB ]"
    # 1 Mbi of marging to not resize partition
    local resize_margin=$(( 1024*1024/$sector_size ))

    if [ $free_space -gt $resize_margin ] ; then
          cos_printf "Resizing partition number $root_part_number [$root_part] to 100pc of the disk=>"
          if printf "yes\n100%%" | parted -a opt ---pretend-input-tty $root_disk resizepart $root_part_number ; then
            cos_printf "OK. Resizing root file system $root_part =>" 
            if resize2fs $root_part ; then
              cos_echo " resize2fs OK"
            else
              cos_echo " resize2fs FAILED."
            fi # resize2fs
          else 
            cos_echo "parted FAILED."
          fi # resizepart 
          cos_echo "Status of the filesystem after resize:"
	  cos_echo "$(parted -s $root_disk 'print free')"
          cos_echo "$(df -h)"
        else 
          cos_echo "Resize partition ignered as free space is less than free space margin=$resize_margin sector"
     fi # in margin

  fi # is last partition

  cos_echo "[resize] finised."

}


cos_do_ntpdate() {
   local srv=$1

   if ! command -v ntpdate &> /dev/null  ; then
     echo "[ntpdate] ntpdate not found. Skipping."
     return 0
   fi

   cos_echo "[ntpdate] configure time servers ..."
cat > /etc/default/ntpdate <<EOF
# created by composeOS
# Configuration script used by ntpdate-sync script

# Set to "yes" to write time to hardware clock on success
UPDATE_HWCLOCK="no"
# Time servers
EOF

    printf 'NTPSERVERS="' >> /etc/default/ntpdate
    for ns in $srv ; do
      printf " $ns" >> /etc/default/ntpdate
      cos_printf "[$ns]"
    done
    echo '"' >> /etc/default/ntpdate
    
    cos_echo 
    cos_echo "[ntpdate] finished."

}

cos_do_ntpd() {
  local srv=$1

   if ! command -v ntpd &> /dev/null ; then
     cos_echo "[ntpd] ntpd not found. Skipping"
     return 0
   fi

   cos_echo "[nptd] configure time servers ..."
   echo "# created by composeOS" > /etc/ntp.conf
   for ns in $srv ; do
      echo "server $ns" >> /etc/ntp.conf
      cos_printf " [$ns] "
    done

cat >> /etc/ntp.conf <<EOF
# Using local hardware clock as fallback
# Disable this when using ntpd -q -g -x as ntpdate or it will sync to itself
#server 127.127.1.0
#fudge 127.127.1.0 stratum 14
# Defining a default security setting
restrict -4 default notrap nomodify nopeer noquery
restrict -6 default notrap nomodify nopeer noquery

restrict 127.0.0.1    # allow local host
restrict ::1          # allow local host
EOF
  cos_echo
  cos_echo "[nptd] finished."

}

cos_do_chrony() {
  local srv=$1

  if ! command -v chronyd &> /dev/null  ; then
     cos_echo "[chronyd] chronyd not found. Skipping." 
     return 0
  fi

  cos_echo "[chronyd] configure time servers ..."
  
  if [ ! -f /etc/chrony.conf.bkp -a -f /etc/chrony.conf ] ; then
    echo "Backing up /etc/chrony.conf"
    cp /etc/chrony.conf /etc/chrony.conf.bkp
  fi

cat > /etc/chrony.conf <<EOF
# created by composeOS
#pool pool.ntp.org iburst
#initstepslew 10 pool.ntp.org
makestep 1.0 3
driftfile /var/lib/chrony/drift
rtcsync
cmdport 0
EOF

  for ns in $srv ; do
    echo "server $ns iburst" >> /etc/chrony.conf
    cos_printf " [$ns ]"
  done
  
  echo "initstepslew 10 $srv" >> /etc/chrony.conf
  echo "# created by composeOS" >> /etc/chrony.conf

  cos_echo
  cos_echo "[chronyd] finished."

}

cos_do_setup_swap(){
  local swap_path=$1
  local swap_size=$2

  cos_echo "[swap_setup] configuring swap space ..."
  if [ $swap_size -le 0 ]; then
    cos_echo "Skipping swap as swap.size=$swap_size <=0"
    cos_echo "[swap_setup] finished."
    return 0
  fi
  
  if [ -f $swap_path ] ; then
       local actual_size=$(stat -c%s $swap_path)
       local desired_size=$(($swap_size * 1024 * 1024))
       if [ $actual_size -eq $desired_size ] ; then 
         cos_echo "Swap file $swap_path of desired size $swap_size is present. nothing to do."
       else
         cos_echo "Existing swap file $swap_path has a diffent size of required actual=$actual_size vs required=$desired_size"
	 cos_echo "creating new file of desired size $swap_size"
         create_swap_file $swap_path $swap_size
       fi

   else
      cos_echo "$swap_path does not exists. Creating new file of the desired size $swap_size"
      create_swap_file $swap_path $swap_size
   fi
   cos_echo "[swap_setup] finished."
}


cos_do_ifup_interfaces() {

  local cos_cnf_network=$1

  if [ ! -f /etc/network/interfaces ] ; then
    cos_echo "[ifaces_ifup] no /etc/network/interfaces file. skipped."
    return 0
  fi

  cos_get_cnf_arr_len "$cos_cnf_network" ".ifaces"
  local iface_len=$__
  cos_get_cnf_val "$cos_cnf_network" ".domain" ""
  local domain=$__
  cos_get_cnf_arr "$cos_cnf_network" ".dns" ""
  local dns=$__
  
  cos_echo "[ifaces_ifup] Configuring $iface_len network interfaces ..."

  if [ -f "/etc/network/interfaces" -a ! -f "/etc/network/interfaces.bkp" ] ; then
     mv /etc/network/interfaces /etc/network/interfaces.bkp    
  fi
  
   echo "# created by compososeOS" > /etc/network/interfaces
cat >> /etc/network/interfaces <<EOF
# /etc/network/interfaces -- configuration file for ifup(8), ifdown(8)

# The loopback interface
auto lo
iface lo inet loopback

# ComposeOS network entries

EOF
    
  iface_len=$((iface_len-1))
  for i in $(seq 0 $iface_len) ; do
      add_network_iface "$cos_cnf_network" $i "$dns" "$domain"
  done
  echo "# end composeOS interfaces" >> /etc/network/interfaces


  cos_echo "[ifaces_ifup] finished."
}

cos_do_openrc_interfaces() {

  local cos_cnf_network=$1
  

  if [ ! -f /etc/conf.d/network ] ; then
    cos_echo "[ifaces_openrc] no /etc/conf.d/network file. skipped."
    return 0
  fi

  cos_get_cnf_arr_len "$cos_cnf_network" ".ifaces"
  local iface_len=$__
  cos_get_cnf_val "$cos_cnf_network" ".domain" ""
  local domain=$__
  cos_get_cnf_arr "$cos_cnf_network" ".dns" ""
  local dns=$__
  

  cos_echo "[ifaces_openrc] Configuring $iface_len network interfaces ..."


  if [ -f "/etc/conf.d/network" -a ! -f "/etc/conf.d/network.bkp" ] ; then
     mv /etc/conf.d/network /etc/conf.d/network.bkp    
  fi

  echo "# created by composeOS" > /etc/conf.d/network

  rm -f ${COS_ETC}/net-*.json
  rm -f ${COS_ETC}/net-*.txt

  iface_len=$((iface_len-1))
  for i in $(seq 0 $iface_len) ; do
    cos_get_cnf_obj "$cos_cnf_network" ".ifaces[$i]" "$COS_DEFAULT_IFACE"
    local if_obj=$__
    cos_get_cnf_val "$if_obj" ".iface" "eth0"
    local if=$__
    cos_get_cnf_val "$if_obj" ".enabled" "true"
    local en=$__ 
    if [ "$en" = "true" ] ; then
     cos_echo "IFACE:$if enabled with conf=$if_obj"
     echo "# composeOS interface $i iface=$if conf=$if_obj" >> /etc/conf.d/network
     echo "ifup_$if=\"/lib/composeos/net.sh $if up\"" >> /etc/conf.d/network
     echo "ifdown_$if=\"/lib/composeos/net.sh $if down\"" >> /etc/conf.d/network
    fi
    echo $if_obj > ${COS_ETC}/net-$if.json
  done

  echo "# end composeOS interfaces" >> /etc/conf.d/network

  # create resolv.conf
  if [ -f /etc/resolv.conf -a ! -f /etc/resolv.conf.bkp ]; then
    cos_printf "Backing up resolv.conf..."
    if cp /etc/resolv.conf /etc/resolv.conf.bkp; then
      cos_echo "OK"
    else
      cos_echo "FAILED - res=$?"
    fi
  fi

  if [ ! -z "$dns" -o ! -z "$domain" ]; then
    echo "# created by composeOS - static" > /etc/resolv.conf
    if [ ! -z "$domain" ]; then
      cos_echo "adding domain $domain to resolv.conf"
      echo "domain $domain" >> /etc/resolv.conf
      printf "$domain" > ${COS_ETC}/net-domain.txt
    fi
    if [ ! -z "$dns" ]; then
      cos_echo "Adding dns [$dns] to resolv.conf"
      printf "$dns" > ${COS_ETC}/net-dns.txt
      for d in "$dns" ; do
         echo "nameserver $d" >> /etc/resolv.conf
      done
    fi
    echo "# end composeOS resolv.conf - static" >> /etc/resolv.conf
  else
    cos_echo "Restoring default resolv.conf"
    [ -f /etc/resolv.conf.bkp ] && cp /etc/resolv.conf.bkp /etc/resolv.conf
  fi

  cos_echo "[ifaces_openrc] finished."

}

cos_do_swapon() {
  local sjson=$1


  cos_echo "[SWAPON] Activanting swap ..."
  cos_get_cnf_val "$sjson" ".size" 1000
  local swap_size=$__
  if [ $swap_size -gt 0 ] ; then
    cos_get_cnf_val "$sjson" ".path" "${COS_MAINSTORAGE}/swapfile"
    local swap_path=$__
    cos_get_cnf_val "$sjson" ".zswap" 20
    local zswap=$__
    cos_get_cnf_val "$sjson" ".zswap_algo" "lz4"
    local zswap_algo=$__
    cos_get_cnf_val "$sjson" ".zswap_pool" "z3fold"
    local zswap_pool=$__

    activate_swap $swap_path $zswap $zswap_algo $zswap_pool
  else
    cos_echo "SWAP is disbled as swap.size=$swap_size MiB"
  fi

  cos_echo "[SWAPON] finished."


}

cos_do_cpuset() {
  local gov=$1
  local ncores=$(nproc --all)

  cos_echo "[CPUSET] Setting CPU governor for $ncores..."
  if [ ! -z $gov ] ; then
    ncores=$((ncores - 1))
    local i=
    for i in $(seq 0 $ncores); do 
       cos_printf "set governor $gov for core $i:"
       if /usr/bin/cpufreq-set -c $i -r -g $gov ; then
         cos_echo "OK"
       else
         cos_echo "FALIED"
      fi
    done
    cos_echo "note: not all boards support freq scalining yet"
  else
    cos_echo "No custom governor set. skipping."
  fi
  cos_echo "[CPUSET] finished."

}

cos_boot() {

  mkdir -p ${COS_RUN_DIR}
  date > ${COS_BOOT_TIME}

  init_cos_boot_log
  cos_echo "----------------------"
  cos_echo "composeOS BOOT"
  cos_echo "----------------------"
  cos_echo "Start: $(date)"

  # console only int message only
  echo "[BOOT] composeOS started"
  cos_echo "[BOOT] composeOS started"

  # Check and load configuration
  if [ ! -f "$COS_CONF_FILE" ] ; then
      cos_echo "composeOS configuration file $COS_CONF_FILE not found. No composeOS configuration steps will be attempted."
      return 1
  fi

  if cos_load_cnf ; then
      cos_echo "[CONF] $COS_CONF_FILE loaded."
  else 
      cos_echo "composeOS configuration file $COS_CONF_FILE failed to load 'start' and/or 'compose' sections. No composeOS configuration steps will be attempted."
      return 1
  fi 

  # 1st mount desired devices
  cos_get_cnf_obj "$cos_cnf_start" ".mount" "$COS_DEFAULT_MOUNT"
  cos_do_mount $__

  # 2nd check if config file changed to apply changes
  local COS_DO_CHANGES=0
  md5sum -c -s $COS_CONF_FILE_MD5 2> /dev/null
  if [ $? -eq 0 ] ; then
    cos_echo "composeOS configuration file did not changed no changes will be done during start."
    COS_DO_CHANGES=1
  else
    cos_echo "composeOS configuration file changed. Changes will be applied during start."
    COS_DO_CHANGES=0
  fi
  set -e
  # 3rd Apply config changes
  if [ $COS_DO_CHANGES -eq 0 ] ; then
	
	# Preamble basic creation of dirs and setting
        cos_echo "[CONF] ComposeOs confirguration started..."
        mkdir -p ${COS_ETC}
        

        # 3.0 hwclock
        cos_get_cnf_val "$cos_cnf_start" ".hwclock" "false"
        cos_echo "[HWCLOCK] configuring clock to $__ ..."
        if [ "$__" = "false" ]; then
          if [ -f /etc/runlevels/boot/hwclock ]; then
            /sbin/rc-update -q del hwclock
            cos_echo "hwclock del from boot res='$?'"
          else
            cos_echo "hwclock was inactive"
          fi
          if [ ! -f /etc/runlevels/boot/swclock ]; then
            /sbin/rc-update -q add swclock boot
            cos_echo "add swclock to boot res='$?'"
          else
            cos_echo "swclock is active"
          fi
        else
          if [ -f /etc/runlevels/boot/swclock ]; then
            /sbin/rc-update -q del swclock boot
            cos_echo "swclock del from boot res='$?'"
          else
            cos_echo "swclock was inactive"
          fi
          if [ ! -f /etc/runlevels/boot/hwclock ]; then
            /sbin/rc-update -q add hwclock boot
            cos_echo "add hwclock to boot res='$?'"
          else
            cos_echo "hwclock is active"
          fi
        fi
        cos_echo "[HWCLOCK] finished."

        # 3.1 resize
	cos_get_cnf_val "$cos_cnf_start" ".resize_root_fs" "true"
	if [ "$__" = "true" ]; then
	    cos_do_resize
	fi
	
	#3.2 hostname
        cos_get_cnf_val "$cos_cnf_start" ".hostname" "cos"
        cos_echo "[HOSTNAME] change hostname to $__"
    	echo $__ > /etc/hostname
        cos_echo "[HOSTNAME] finished."

	#3.2 NTP
        cos_get_cnf_arr "$cos_cnf_start" ".ntp_servers" "$COS_DEFAULT_TIMESERVERS"
        local tms=$__
    	cos_do_ntpd "$tms"
	cos_do_ntpdate "$tms"
	cos_do_chrony "$tms"

	#3.3 Swap file management
	cos_get_cnf_val "$cos_cnf_start" ".swap.size" 0
	local swap_size=$__
	cos_get_cnf_val "$cos_cnf_start" ".swap.path" "${COS_MAINSTORAGE}/swapfile"
	local swap_path=$__
	cos_do_setup_swap $swap_path $swap_size

	#3.4 configure network
	cos_get_cnf_obj "$cos_cnf_start" ".network" "$COS_DEFAULT_NETWORK"
	local net=$__
        cos_do_ifup_interfaces   "$net" 
	cos_do_openrc_interfaces "$net"

        #3.5 change podman engine to set storage to main storage
        cos_echo "[PODMAN] Setting up podman storage ..."
        mkdir -p ${COS_MAINSTORAGE}/podman
        if [ -f /etc/containers/storage.conf ] ; then
          [ ! -f /etc/containers/storage.conf.bkp ] && cp /etc/containers/storage.conf /etc/containers/storage.conf.bkp
          cat /etc/containers/storage.conf.bkp | dasel put -r toml -t string -v "${COS_MAINSTORAGE}/podman" 'storage.graphroot' > /etc/containers/storage.conf
          local pstg=$(dasel -f /etc/containers/storage.conf -r toml)
          cos_echo "Current podmand storage options:"
          cos_echo "$pstg"
        fi
        cos_echo "[PODMAN] finished."

        #3.6 Setting up up wait for time
        cos_echo "[WAITTIME] Setting up wait time service..."
        if [ -f /etc/conf.d/chrony-wait ] ; then
          cos_get_cnf_val "$cos_cnf_start" ".wait_time" "true"
          if [ "$__" = "true" ] ; then
            cos_printf "enabling wait time service ..."
            if cat /etc/conf.d/chrony-wait | grep 'DISABLE_WAIT=no' ; then
              cos_echo "Already enabled."
            else
              sed -i 's/DISABLE_WAIT=yes/DISABLE_WAIT=no' /etc/conf.d/chrony-wait
              cos_echo "enabled."
            fi
          else
            cos_printf "disabling wait time service ...".
            if cat /etc/conf.d/chrony-wait | grep 'DISABLE_WAIT=yes' ; then
              cos_echo "already disabled."
            else
              sed -i 's/DISABLE_WAIT=no/DISABLE_WAIT=yes' /etc/conf.d/chrony-wait
              cos_echo "disabled."
            fi
          fi
        else
          cos_echo "chrony-wait not found. skipping"
        fi
        cos_echo "[WAITTIME] finished."

        #3.7 Set timezone
        cos_echo "[TIMEZONE] Setting up timezone"
        cos_get_cnf_val "$cos_cnf_start" ".timezone" "Universal"
        set_timezone "$__"
        cos_echo "[TIMEZONE] finished."


        #3.Last Generate cheksum for configuration
        cos_echo "[MD5] updating md5 for composeos.yml"
        cos_generate_conf_file_md5
        cos_echo "[CONF] finished."

  fi
   
  # 4th activate swap
  cos_get_cnf_obj "$cos_cnf_start" ".swap" $COS_DEFAULT_SWAP
  cos_do_swapon "$__"


  #5th create baseline env
  cos_echo "[RUNENV] Setting up env file..."
  [ -f /lib/composeos/env ] && cat /lib/composeos/env | grep -v '^#' | grep -v '^$'  > ${COS_ENV_FILE}
  [ ! -f ${COS_ENV_FILE} ] && touch ${COS_ENV_FILE}
  local tz="Universal"
  if [ -L /etc/localtime ]; then
    local t=$(readlink /etc/localtime)
    tz=${t#/usr/share/zoneinfo/}
  fi
  echo "COS_MAINSTORAGE=${COS_MAINSTORAGE}" >> ${COS_ENV_FILE}
  echo "TZ=$tz" >> ${COS_ENV_FILE}
  echo "TAG=latest" >> ${COS_ENV_FILE}
  cos_echo "$(cat ${COS_ENV_FILE})"
  cos_echo "[RUNENV] finished."
  

  # 6th setting governor
  cos_get_cnf_obj "$cos_cnf_start" ".governor" ""
  cos_do_cpuset "$__"

  # 7th excecute custom boot commands
  cos_echo "[BOOT_CMD] Runing custom boot commands..."
  cos_get_cnf_val "$cos_cnf_start" ".extra_boot_cmd" ""
  local scr=$__
  if [ ! -z "$scr" ] ; then
    cos_run_script "custom_boot" "${scr}" "root"
  else
    cos_echo "no extra_boot_cmd provided. skipping"
  fi
  cos_echo "[BOOT_CMD] finished."

  
  cos_echo "[BOOT] composeOS finished."
  echo "[BOOT] composeOS finished."
}

