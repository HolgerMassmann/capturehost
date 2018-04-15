#!/bin/bash

# Need script dir to source other scripts.
DIR="${BASH_SOURCE%/*}"
if [[ -z $DIR || ! -d $DIR ]]; then
  DIR=$(pwd)
fi
# echo "DIR=${DIR}"

# Defines log function
. "${DIR}/log_def.sh"

function usage() {
  log "Usage: $(basename ${0}) message"
  exit 1
}

if [[ $# -ne 1 ]]; then
  usage
  exit  1
fi

# MQ broker configuration settings 
. "${DIR}/broker_def.sh"

# Publish function
. "${DIR}/publish_def.sh"

# Sends the message
message="$1"
publish "${message}"
ret=$?
if [[ $ret -ne 0 ]]; then
  log "Publish failed (return code=$ret)"
else
  log "Publish succeeded."
fi
