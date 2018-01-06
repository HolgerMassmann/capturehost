#!/bin/bash

base_dir=$HOME/capture
program_name=raspistill
program_wrapper=${base_dir}/bin/capture_flipped.sh

img_dir=/var/lib/tomcat8/webapps/svc/img
latest_img=${img_dir}/latest.jpg
log_file=${base_dir}/logs/watchdog.log

#
# Contains the process id of the running raspistill process.
#
pid=0

#
# Logging funtion (replace with generic version later).
#
function log() {
  local message=$1
  local tstamp=$( date '+%FT%T' )
  echo "${tstamp}: ${message}" >> ${log_file}
}

function restart_image_capture() {
  log "Terminating process ${pid}"
  # kill $( pgrep ${program_name} )
  log "Restarting image capture using ${program_wrapper} 3000 640 400 r_ ${img_dir}"
  ${program_wrapper} 3000 640 400 r_ ${img_dir}
}

#
# Verfiy latest.jpg is not older then n seconds.
# If too old restart raspistill process.
#
function isalive() {
  local max_age_seconds=60
  if [ $# -eq 1 ]; then
    max_age_seconds=$1
  fi
  now=$( date '+%s' )
  latest_img_tstamp=$( date -r ${latest_img} '+%s' )
 
  age=$(( now - latest_img_tstamp ))
  if [ ${age} -gt ${max_age_seconds} ]; then
    log "${latest_img} is outdated, restarting image capture."
  else
    log "${latest_img} is up to date."
  fi
}

function process_exists() {
  pid=$( pgrep ${program_name} )
  if [ $? -eq 0 ]; then
    log "$( ps -fp ${pid} )"
    log "${program_name} running, checking liveness."
    #
    # If the process id is valid, check whether
    # latest.jpg is up to date.
    #
    isalive
  else
    restart_image_capture
  fi
}

process_exists
