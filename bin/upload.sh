#!/bin/bash

#
# Base directories.
#
basedir=/home/pi/capture
logdir=${basedir}/logs
upload_log_file=${logdir}/upload.log
bindir=${basedir}/bin

#
# Upoad host config.
#
upload_host=raspberry.fritz.box
upload_user=pi
img_base_dir=/var/images
src_dir=${img_base_dir}
dest_dir=/var/images/raspi2

#
# Scripts to call on the receiving side.
#
archive_cmd=svc/bin/run_archive.sh
encode_cmd=svc/bin/run_encode.sh

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
  log "Usage: `basename $0` [day hour-of-day]"
}

if [ $# -ne 0 -a $# -ne 2 ]; then
  usage
  exit 1
fi

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
pattern=$( printf 'pi2_%d%02d%02d' ${month#0} ${day#0} ${previous_hour#0} )

log "Matching ${pattern}*"
log "Copying $( ls ${src_dir}/${pattern}* | wc -l ) files."

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

log "Copy completed, running ${archive_cmd} on upload host..."
log "ssh ${upload_user}'@'${upload_host} ${archive_cmd} ${pattern}* "

ssh ${upload_user}'@'${upload_host} ${archive_cmd} ${pattern}*
ret=$?
if [ $ret -ne 0 ]; then
  log "Uploading of images failed (retcode=$ret)."
  exit 1
fi

log "ssh ${upload_user}'@'${upload_host} ${encode_cmd} ${img_directory} ${frame_rate}"
ssh ${upload_user}'@'${upload_host} ${encode_cmd}  ${img_directory} ${frame_rate}
