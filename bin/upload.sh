#!/bin/bash

#
# Base directories.
#
basedir=/home/pi/capture
logdir=${basedir}/logs
upload_log_file=${logdir}/upload.log
bindir=${basedir}/bin
DIR="$bindir"

#
# Upoad host config.
#
upload_host=gaspberrypi.fritz.box
upload_user=pi
img_base_dir=/var/lib/tomcat8/webapps/svc/img
dest_dir=${img_base_dir}
#
# Frame rate for encode call later.
#
frame_rate=24

#
# Error Codes
#
readonly ERR_SUCCESS=0
readonly ERR_CONFIG=1
readonly ERR_UPLOAD=2

log_file="${upload_log_file}"
# Defines log function
. "${DIR}/log_def.sh"

# MQ broker configuration settings 
. "${DIR}/broker_def.sh"

# Publish function
. "${DIR}/publish_def.sh"

#
# Logging utility
# Uses global variable upload_log_file
# Parameters: 1 - message the message to print
#
# function log() {
#   local message=$1
#   local tstamp=$( date '+%FT%T' ) 
#   echo "${tstamp}: ${message}" | tee -a ${upload_log_file}
# }

function usage() {
  log "Usage: `basename $0` [day hour-of-day]"
}

#
# Send an email notification.
#
function notify() {
  local message=$1
}

#
# Verify ssh to upload host is working.
#
function check_upload_host() {
  local user=$1
  local host=$2

  log "Checking ssh connection to host ${host}..."
  ssh -o ConnectTimeout=10 ${user}'@'${host} date > /dev/null
  ret=$?
  if [[ $ret -ne 0 ]]; then
    log "Connect to upload host ${host} failed with ret=${ret}, sending notification"
    notify "Connect to upload host ${host} failed with ret=${ret}"
  else
    log "Connection to upload host ${host} seems to work."
  fi
}

# Logs the message and publishes it on the message broker.
function logpub() {
  local message="$1"
  log "$message"
  publish "$message"
}

#
# Main script starts here.
#
if [ $# -ne 0 -a $# -ne 2 ]; then
  usage
  exit 1
fi

#
# Perform some verifications.
#
if [ ! -d ${basedir} ]; then
  log "${basedir} does not exist, exiting."
  exit ERR_CONFIG
fi
if [ ! -d ${bindir} ]; then
  log "${bindir} does not exist, exiting."
  exit ERR_CONFIG
fi
if [ ! -d ${logdir} ]; then
  log "${logdir} does not exist, exiting."
  exit ERR_CONFIG
fi
if [ ! -d ${dest_dir} ]; then
  log "${dest_dir} does not exist, exiting."
  exit ERR_CONFIG
fi

check_upload_host ${upload_user} ${upload_host}

#
# Handle optional input parameters day and  hour-of-day.
#
if [ $# -eq 2 ]; then
  day=$1
  hour_of_day=$2
else
  day=$( date '+%d' )
  hour_of_day=$( date '+%H' )
fi
log "Using day=${day}, hour_of_day=${hour_of_day}"

#
# Work from image directory (easier)
#
cd ${img_base_dir}
if [ $? -ne 0 ]; then
  log "Could not change directory to ${img_base_dir}, exiting."
  exit ERR_CONFIG
fi

#
# Need year later.
#
year=$( date '+%Y' )

#
# Calculate year month day hour string.
#
raw_month=$( date '+%m' )
month=$( echo ${raw_month} | sed -e 's/^0//' )

#
# Use bash arithmetic context for calculations.
#
if [ $# -ne 0 ]; then
  previous_hour=${hour_of_day}
else
  previous_hour=$(( `date '+%k'` - 1 ))
  #
  # Handle hour 0 properly (will result in -1 above instead of 23).
  if [ ${previous_hour} -lt 0 ]; then
    previous_hour=23
    day=$(( $day - 1 ))
  fi
fi

log "Using day=${day}, previous hour=${previous_hour}"

#
# Build directory name for encode call later.
#
img_directory=$( printf '%04d/%02d/%02d/%02d' ${year} ${raw_month#0} ${day#0} ${previous_hour#0} )

#
# Build search pattern for selecting images to copy.
#
pattern=$( printf 'r_%d%02d%02d' ${month#0} ${day#0} ${previous_hour#0} )

log "Matching ${pattern}*"
log "Copying $( ls ${img_base_dir}/${pattern}* | wc -l ) files."

logpub "Copying images to upload host ${upload_host}:${dest_dir}"
scp -p ${pattern}* ${upload_user}'@'${upload_host}:${dest_dir}
ret=$?

if [ $ret -ne 0 ]; then
  logpub "Could not copy images to upload host."
  exit 2
else
  log "Removing images matching pattern ${pattern}*.jpg after successfull copy."
  rm ${pattern}*.jpg
fi

log "`date`: Copy completed, running archive on upload host..."
logpub "ssh ${upload_user}'@'${upload_host} svc/bin/run_archive.sh ${pattern}* "

ssh ${upload_user}'@'${upload_host} svc/bin/run_archive.sh ${pattern}*
ret=$?
if [ $ret -ne 0 ]; then
  log "Uploading of images failed ($ret)."
  exit 1
fi

logpub "ssh ${upload_user}'@'${upload_host} svc/bin/run_encode.sh ${img_directory} ${frame_rate}"
ssh ${upload_user}'@'${upload_host} svc/bin/run_encode.sh ${img_directory} ${frame_rate}

logpub "Upload done."
