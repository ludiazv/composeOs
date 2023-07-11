# Json helper funtions for composeos


cos_get_cnf_keys() {
  local json=$1

  [ -z $json ] && json="{}"
  __=$(echo "$json" | jq -cM keys | jq -r '.[]')
  return 0

}

cos_get_cnf_keys_len() {

  local json=$1

  [ -z $json ] && json="{}"
  __=$(echo "$json" | jq -cM keys | jq -r '. | length')
  return 0

}

cos_cnf_has_key() {
  local json=$1
  local key=$2

  if echo "$json" | jq -cM keys | jq -r '@sh' | grep "'${key}'" ; then
    return 0
  else
    return 1
  fi
  #local t=$(echo $json | jq -r "$key")
  #if [ "$t" = null ] ; then
  #  return 1
  #else
  #  return 0
  #fi
}

cos_get_cnf_val() {
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

cos_get_cnf_arr() {
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

cos_get_cnf_arr_len() {
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

cos_get_cnf_obj() {
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


