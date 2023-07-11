source /etc/composeos.conf

# Log functions
# --------------
init_cos_boot_log() {
  [ ! -f $COS_BOOTLOG_FILE ] && touch $COS_BOOTLOG_FILE
  local ll=$(cat $COS_BOOTLOG_FILE | wc -l)
  if [ $ll -gt $COS_MAX_LOG_LINES ] ; then
    local t=$((COS_MAX_LOG_LINES - COS_MAX_LOG_PRUNE))
    echo "...rotated..." > /tmp/tmpcosboot.log
    tail -n $t $COS_BOOTLOG_FILE >> /tmp/tmpcosboot.log
    cp /tmp/tmpcosboot.log $COS_BOOTLOG_FILE
    rm -f /tmp/tmpcosboot.log 
  fi
  echo "composeOS boot log init" >>  $COS_BOOTLOG_FILE
  #echo "composeOS boot log initialized"
  return 0
}

cos_printf() {
  local out="$*"
  [ "$COS_DEBUG" = "true" ] && printf "$out"
  printf "$out" >> $COS_BOOTLOG_FILE
}

cos_echo() {
  local out="$*"
  [ "$COS_DEBUG" = "true" ] && echo "$out"
  echo "$out" >> $COS_BOOTLOG_FILE
}
