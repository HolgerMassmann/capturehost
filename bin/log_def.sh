#!/bin/bash
#
# Logging utility
# Uses global variable log_file
# Parameters: 1 - message the message to print
#
function log() {
  local message=$1
  local tstamp=$( date '+%FT%T' ) 
  if [[ -z ${log_file} || ! -w ${log_file} ]]; then
    echo "${tstamp}: ${message}"
  else
    echo "${tstamp}: ${message}" >> ${upload_log_file}
  fi
}

