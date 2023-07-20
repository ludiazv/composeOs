# composeos functions for run
source /lib/composeos/base.sh


[ -f ${COS_ENV_FILE} ] && source ${COS_ENV_FILE}


cos_do_prepare_run() {
  local run=$1
  local genv=$2
  local fsusr=$3
  local usr=$4

  
  cos_get_cnf_keys_len "$run"
  local run_len=$__
  cos_echo "[PREAPRERUN] Setting up run #${run_len} stacks with user $usr..."

  if [ $run_len -eq 0 ] ; then
    cos_echo "[PREPARERUN] no stacks defined. skipping."
    cos_echo "[PREPARERUN] finished."
    __=""
    return 0
  fi

  cos_get_cnf_keys "$run"
  local keys=$__
  
  local enabled_stacks=""
  local stack_name=
  for stack_name in "$keys" ; do
    
    cos_get_cnf_obj "$run" ".${stack_name}" "${COS_DEFAULT_RUN}"
    local stack=$__
    
    # Get the stack properties
    cos_get_cnf_val "$stack" ".enabled" "true"
    local enabled=$__
    cos_get_cnf_obj "$stack" ".populate" "${COS_DEFAULT_POPULATE}"
    local populate=$__
    cos_get_cnf_val "$stack" ".yml" ""
    local yml=$__
    cos_get_cnf_val "$stack" ".file" ""
    get_path "$__" "${COS_STACK_DIR}"
    local file=$__
    cos_get_cnf_obj "$stack" ".env" "${COS_DEFAULT_POPULATE}"
    local extra_env=$__

    cos_printf " => processing stack '$stack_name' [enabled:$enabled] "
  
    if [ ! -f $file -a -z $yml ] ; then
      cos_echo "invalid file or yml property provided. skipping. <="
      continue
    fi

    # Create STACK_FOLDER
    local stack_folder="${COS_MAINSTORAGE}/${stack_name}"
    mkdir -p ${stack_folder}
    chown $fsusr:$fsusr ${stack_folder}

    # Prepare run files
    echo "$usr" > ${COS_RUN_DIR}/cs-${stack_name}.usr
    echo "$enabled" > ${COS_RUN_DIR}/cs-${stack_name}.enabled
    cos_printf "[cs-${stack_name}.usr][cs-${stack_name}.enabled]"

    if [ ! -z $yml ] ; then
      echo "$yml" > ${COS_RUN_DIR}/cs-${stack_name}.yml
      cos_printf "[yml -> cs-${stack_name}.yml]"
    fi

    if [ -f $file ] ; then
      cp $file ${COS_RUN_DIR}/cs-${stack_name}.yml
      cos_printf "[$file -> cs-${stack_name}.yml]"
    fi

    # Create env
    # 1st the are the default values inline in the compose.yml file marked with ##
    # 2nd general environment
    # 3rd gloval environment
    # 4th the forced values in the compose.yml file marked with #!
    # 5th extra env defined in the stack
    
    # 1st 
    touch ${COS_RUN_DIR}/cs-${stack_name}.env
    cat ${COS_RUN_DIR}/cs-${stack_name}.yml | grep '^##\s*' | sed 's/^##\s*\(.*\)/\1/' >> ${COS_RUN_DIR}/cs-${stack_name}.env
    # 2nd
    [ -f ${COS_ENV_FILE} ] && cat ${COS_ENV_FILE} >> ${COS_RUN_DIR}/cs-${stack_name}.env
    echo "STACK_NAME=${stack_name}" >> ${COS_RUN_DIR}/cs-${stack_name}.env
    echo "STACK_FOLDER=${stack_folder}" >> ${COS_RUN_DIR}/cs-${stack_name}.env
    # 3rd
    echo "${genv}" | jq -r '.[]' >> ${COS_RUN_DIR}/cs-${stack_name}.env
    # 4th
    cat ${COS_RUN_DIR}/cs-${stack_name}.yml | grep '^#!\s*' | sed 's/^#!\s*\(.*\)/\1/' >> ${COS_RUN_DIR}/cs-${stack_name}.env
    #5th
    echo "${extra_env}" | jq -r '.[]' >> ${COS_RUN_DIR}/cs-${stack_name}.env
    chown $usr:$usr ${COS_RUN_DIR}/cs-${stack_name}.*
    cos_echo "[cs-${stack_name}.env] <="
    
    # Populate
    if [ "$populate" = "[]" ] ; then
      cos_echo " => no populate directive defined <="
    else
      cos_populate "$populate" "${stack_folder}"
    fi
  

    if [ "$enabled" = "true" ] ; then
      enabled_stacks="$enabled_stacks $stack_name"
    fi

  done

  __=$enabled_stacks
  cos_echo "[PREPARERUN] finished."
  return 0
}

# Entry point for run
cos_run() {

  init_cos_boot_log
  cos_echo "----------------------"
  cos_echo "composeOS RUN"
  cos_echo "----------------------"
  cos_echo "Start: $(date)"
  date > ${COS_RUN_TIME}

  # console only int message only
  echo "[RUN] composeOS started"
  cos_echo "[RUN] composeOS started"


  # Check and load configuration
  if [ ! -f "$COS_CONF_FILE" ] ; then
      cos_echo "composeOS configuration file $COS_CONF_FILE not found. No composeOS run steps will be attempted."
      return 1
  fi

  if cos_load_cnf ; then
      cos_echo "[CONF] $COS_CONF_FILE loaded."
  else 
      cos_echo "composeOS configuration file $COS_CONF_FILE failed to load 'start' and/or 'compose' sections. No composeOS configuration steps will be attempted."
      return 1
  fi 


  #1st Init podman service if required
  cos_get_cnf_val "$cos_cnf_compose" ".daemon" "false"
  if [ "$__" = "true" ] ; then
    cos_echo "[DAEMON] Starting podman service..."
    if ps -e | grep 'podman system service' | grep -v 'grep' ; then
      cos_echo "podman service is running"
      [ -f ${COS_RUN_DIR}/podman.pid ] && cos_echo "PID=$(cat ${COS_RUN_DIR}/podman.pid)"
    else
      /usr/bin/podman system service -t 0 &
      local ppid=$!
      cos_echo "Podman service started with pid=$ppid"
      echo $ppid > ${COS_RUN_DIR}/podman.pid
    fi
    cos_echo "[DAEMON] Finished."
  else
    cos_echo "[DAEMON] Not started as $__ was selected in daemon property."
  fi

  #2nd Run pres_cript if required
  cos_echo "[PRE_SCRIPT] pre script..."
  cos_get_cnf_val "$cos_cnf_compose" ".pre_script" ""
  local scr=$__
  if [ ! -z "$scr" ] ; then
    cos_run_script "pre_script" "${scr}" "root"
  else
    cos_echo "no pre_script provided. skipping"
  fi
  cos_echo "[PRE_SCRIPT] finished."



  #3rd Top level populate
  cos_echo "[TOPPOPULATE] Populating Top level..."
  cos_get_cnf_obj "$cos_cnf_compose" ".populate" "[]"
  cos_populate "$__" "${COS_MAINSTORAGE}"
  cos_echo "[TOPOPULATE] finished."


  #4th Prepare run
  local enabled_stacks=""
  cos_get_cnf_obj "$cos_cnf_compose" ".run" "{}"
  local r=$__

  cos_get_cnf_obj "$cos_cnf_compose" ".env" "[]"
  local genv=$__
  cos_echo "[GLOB_ENV] loaded => $genv"

  cos_do_prepare_run "$r" "$genv" "${COS_USER}" "root"
  enabled_stacks=$__

  #cos_get_cnf_obj "$cos_cnf_compose" ".run" "{}"
  #r=$__
  #cos_do_prepare_run "$r" "${COS_USER}"
  #enabled_stacks=$(trim "$enabled_stacks $__")

  # 5th run
  
  cos_get_cnf_obj "$cos_cnf_compose" ".no_run" "false"
  local no_run=$__
  cos_echo "[RUN] Starting stacks [no_run:$no_run]..."
  if [ "$no_run" = "false" ] ; then
    cos_echo "[RUN] starting enabled stacks [$enabled_stacks]->${COS_RUN_DIR}/enabled ..."
    echo "$enabled_stacks" > ${COS_RUN_DIR}/enabled
    
    #Run stacks
    cos_printf "Running stacks [$enabled_stacks]..."
    if /usr/bin/cos up > $COS_RUNLOG_FILE ; then
      cos_echo "OK - log stored in $COS_RUNLOG_FILE"
    else
      cos_echo "FAILED - log stored in $COS_RUNLOG_FILE"
    fi

    #Run post script
    cos_echo "[POST_SCRIPT] post script..."
    cos_get_cnf_val "$cos_cnf_compose" ".post_script" ""
    scr=$__
    if [ ! -z "$scr" ] ; then
      cos_run_script "post_script" "${scr}" "root"
    else
      cos_echo "no post_script provided. skipping"
    fi
    cos_echo "[POST_SCRIPT] finished."
  
  else 
    echo "selected no_run=$no_run. no stack will be started."

  fi
  cos_echo "[RUN] finished."
  return 0

}
