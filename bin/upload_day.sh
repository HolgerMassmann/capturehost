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
upload_host=plusberry.fritz.box
upload_user=pi
img_base_dir=/home/pi/svc_web/img
dest_dir=/svc/data/images/daily

archive_cmd=run_archive_day.sh
prefix=d_

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

function usage() {
  log "Usage: $(basename $0) [prefix] month day"
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
if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage
  exit 1
fi

#
# Perform some verifications.
#
if [[ ! -d ${basedir} ]]; then
  log "${basedir} does not exist, exiting."
  exit $ERR_CONFIG
fi
if [[ ! -d ${bindir} ]]; then
  log "${bindir} does not exist, exiting."
  exit $ERR_CONFIG
fi
if [[ ! -d ${logdir} ]]; then
  log "${logdir} does not exist, exiting."
  exit $ERR_CONFIG
fi

check_upload_host ${upload_user} ${upload_host}

#
# Handle input parameters prefix, month and day.
#
if [[ $# -eq 3 ]]; then
  prefix=$1
  shift
fi

month=$1
day=$2
log "Using prefix=${prefix}, month=${month}, day=${day}"

#
# Work from image directory (easier)
#
cd ${img_base_dir}
if [[ $? -ne 0 ]]; then
  log "Could not change directory to ${img_base_dir}, exiting."
  exit $ERR_CONFIG
fi

#
# Need year later.
#
year=$( date '+%Y' )

#
# Build directory name for encode call later.
#
img_directory=$( printf '%04d/%02d/%02d' ${year} ${month#0} ${day#0} )

#
# Build search pattern for selecting images to copy.
#
pattern=$( printf '%s%d%02d' ${prefix} ${month#0} ${day#0} )

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
logpub "ssh ${upload_user}'@'${upload_host} svc/bin/run_archive_day.sh ${prefix} ${pattern}* "

ssh ${upload_user}'@'${upload_host} svc/bin/run_archive_day.sh ${prefix} ${pattern}*
ret=$?
if [ $ret -ne 0 ]; then
  log "Uploading of images failed ($ret)."
  exit 1
fi

logpub "ssh ${upload_user}'@'${upload_host} svc/bin/run_encode_day.sh ${img_directory} ${frame_rate}"
ssh ${upload_user}'@'${upload_host} svc/bin/run_encode_day.sh ${img_directory} ${frame_rate}

logpub "Upload done."
