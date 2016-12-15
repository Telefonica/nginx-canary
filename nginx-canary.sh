#!/bin/bash

VERSIONS_FILE=/etc/nginx/canary/versions.lua
CONFIG_FILE=/etc/nginx/canary/config.lua

# Parse arguments from command line to assign them as environment variables
parse_args() {
  for arg in "$@"; do
    # Remove leading -
    local arg="$(echo "$arg" | sed -e 's/^-*//')"
    local arg_var="$(echo ${arg%=*} | tr '[:lower:]' '[:upper:]' | sed -e 's/-/_/g')"
    local arg_value="${arg#*=}"
    declare -x -g "$arg_var"="$arg_value"
  done
}

# Prepare a regular expression by escaping characters: []"
# The regular expression is in the form: ^$1.* where $1 has been escaped.
# For example, passing config["partitions"]["canary"] would create ^config\[\"partitions\"\]\[\"canary\"\].*
#
# Input parameters:
# - $1: value to be escaped
prepare_regex() {
  local regex=$1
  for i in [ ] \" ; do
    regex="${regex//$i/\\$i}"
  done
  echo "^$regex.*"
}

# Set a lua variable in a file.
#
# Input parameters:
# - $1: lua file where the variable is set 
# - $2: variable name (e.g. config["partitions"]["canary"])
# - $3: variable value (e.g. 20)
set_lua_var() {
  local file=$1
  local param_key=$2
  local param_value=$3
  local regex=$(prepare_regex "$param_key") 
  local value="$param_key = $param_value"
  grep -q "$regex" "$file" \
    && sed -i "s/$regex/$value/g" "$file" \
    || sed -i "/^return /i $value" "$file"
}

# Set a version for a deployment group in file /etc/nginx/canary/versions.lua.
# If the file already has this deployment group, it updates the value. Otherwise, it adds a new line with
# the version for the deployment group.
#
# Input parameters:
# - $1: Deployment group
# - $2: Version
set_version() {
  local deployment_group=$1
  local version=$2
  set_lua_var "$VERSIONS_FILE" "versions[\"$deployment_group\"]" "\"$version\""
}

# Get all environment variables starting with "VERSION_" (e.g. VERSION_CANARY), extract the deployment group
# converting to lower case (e.g. "canary") and get the version. For each one of these environment variables, 
# it sets the deployment group version in file /etc/nginx/canary/versions.lua
set_versions() {
  for deployment_group_version in $(env | grep "^VERSION_"); do
    local deployment_group_assignment="${deployment_group_version#*_}"
    local deployment_group="$(echo ${deployment_group_assignment%=*} | tr '[:upper:]' '[:lower:]')"
    local version="${deployment_group_assignment#*=}"
    set_version "$deployment_group" "$version"
  done
}

# Set a string configuration parameter in file /etc/nginx/canary/config.lua.
# Note that partitions use set_config_partition function.
#
# Input parameters:
# - $1: configuration parameter key: domain, policy, routing_header or routing_query_param
# - $2: configuration parameter value
set_config_string_param() {
  local param_key=$1
  local param_value=$2
  set_lua_var "$CONFIG_FILE" "config[\"$param_key\"]" "\"$param_value\""
}

# Set the non string configuration parameters in file /etc/nginx/canary/config.lua.
# Not using set_config_string_param because it is boolean or number.
#
# Input parameters:
# - $1: configuration parameter key: cookies
# - $2: configuration parameter value (e.g. true)
set_config_nonstring_param() {
  local param_key=$1
  local param_value=$2
  set_lua_var "$CONFIG_FILE" "config[\"$param_key\"]" "$param_value"
}

# Set a configuration partition in file /etc/nginx/canary/config.lua.
#
# Input parameters:
# - $1: partition name (e.g. "canary")
# - $2: partition value (e.g. 20)
set_config_partition() {
  local param_key=$1
  local param_value=$2
  set_lua_var "$CONFIG_FILE" "config[\"partitions\"][\"$param_key\"]" "$param_value"
}

# Update the configuration file /etc/nginx/canary/config.lua with the partitions from environment variables PARTITION_*.
# This process is achieved by getting all the environment variables starting with "PARTITION_"
# (e.g. PARTITION_CANARY), extracting the deployment group converting to lower case (e.g. "canary")
# and getting the partition.
# For example, if there is an environment variable:
# PARTITION_CANARY=20
# it would set the following configuration line:
# config["partitions"]["canary"]=20
set_config_partitions() {
  for deployment_group_partition in $(env | grep "^PARTITION_"); do
    local deployment_group_assignment="${deployment_group_partition#*_}"
    local deployment_group="$(echo ${deployment_group_assignment%=*} | tr '[:upper:]' '[:lower:]')"
    local partition="${deployment_group_assignment#*=}"
    set_config_partition $deployment_group $partition
  done
}

# Update the configuration file /etc/nginx/canary/config.lua from environment variables:
# - DOMAIN (by default, localhost)
# - COOKIES (by default, true)
# - POLICY (by default, random)
# - ROUTING_HEADER (by default, Deployment-Group)
# - ROUTING_QUERY_PARAM (empty value by default)
set_config() {
  for config_var in DOMAIN POLICY ROUTING_HEADER ROUTING_QUERY_PARAM; do
    if [ ! -z ${!config_var+x} ]; then
      local config_key="$(echo $config_var | tr '[:upper:]' '[:lower:]')"
      local config_value="${!config_var}"
      set_config_string_param "$config_key" "$config_value"
    fi
  done
  for config_var in COOKIES; do
    if [ ! -z ${!config_var+x} ]; then
      local config_key="$(echo $config_var | tr '[:upper:]' '[:lower:]')"
      local config_value="${!config_var}"
      set_config_nonstring_param "$config_key" "$config_value"
    fi
  done
}

parse_args "$@"
set_versions
set_config
set_config_partitions

# Reload nginx with new configuration
if [ -f /var/run/nginx.pid ]; then
  nginx -s reload
fi
