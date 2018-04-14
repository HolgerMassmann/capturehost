#!/bin/bash

#
# Base directories.
#
basedir=/home/pi/capture
logdir=${basedir}/logs
upload_log_file=${logdir}/upload_day.log
bindir=${basedir}/bin

#
# Upoad host config.
#
upload_host=plusberry.fritz.box
upload_user=pi
img_base_dir=/var/images
src_dir=${img_base_dir}
dest_dir=/svc/data/images/daily

#
# Scripts to call on the receiving side.
#
archive_cmd=svc/bin/run_archive_day.sh
encode_cmd=svc/bin/run_encode_day.sh

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

#
# Logging utility
# Uses global variable upload_log_file
# Parameters: 1 - message the message to print
#
function log() {
  local message=$1
  local tstamp=$( date '+%FT%T' ) 
  echo "${tstamp}: ${message}" | tee -a ${upload_log_file}
}

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
if [ ! -d ${src_dir} ]; then
  log "${src_dir} does not exist, exiting."
  exit ERR_CONFIG
fi

function usage() {
  log "Usage: `basename $0` [day]"
}

if [ $# -ne 0 -a $# -ne 1 ]; then
  usage
  exit 1
fi

#
# Handle optional input parameters day and  hour-of-day.
#
if [ $# -eq 1 ]; then
  day=$1
else
  day=$( date '+%d' )
fi
log "Using day=${day}"

#
# Work from image directory (easier)
#
cd ${src_dir}
if [ $? -ne 0 ]; then
  log "Could not change directory to ${src_dir}, exiting."
  exit ERR_CONFIG
fi

#
# Need year later.
#
year=$( date '+%Y' )

#
# Calculate year month day string.
#
raw_month=$( date '+%m' )
month=$( echo ${raw_month} | sed -e 's/^0//' )
log "Using month ${month}"

#
# Build directory name for encode call later.
#
img_directory=$( printf '%04d/%02d/%02d' ${year} ${raw_month#0} ${day#0} )

#
# Build search pattern for selecting images to copy.
#
pattern=$( printf 'pi2_%d%02d' ${month#0} ${day#0} )

log "Matching ${pattern}*"
log "Copying $( ls ${pattern}* | wc -l ) files."

log "Copying images to upload host ${upload_host}:${dest_dir}"
scp -p ${pattern}* ${upload_user}'@'${upload_host}:${dest_dir}
ret=$?

if [ $ret -ne 0 ]; then
  log "Could not copy images to upload host."
  exit 2
else
  log "Removing images matching pattern ${pattern}*.jpg after successfull copy."
  rm ${pattern}*.jpg
fi

log "Copy completed, running archive on upload host..."
log "ssh ${upload_user}'@'${upload_host} ${archive_cmd} ${pattern}* "

# ssh ${upload_user}'@'${upload_host} ${archive_cmd} ${pattern}*
# ret=$?
# if [ $ret -ne 0 ]; then
#   log "Uploading of images failed ($ret)."
#   exit 1
# fi

log "ssh ${upload_user}'@'${upload_host} ${encode_cmd} ${img_directory} ${frame_rate}"
# ssh ${upload_user}'@'${upload_host} ${encode_cmd} ${img_directory} ${frame_rate}

log "Upload completed successfully."

