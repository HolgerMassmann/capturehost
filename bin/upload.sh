#!/bin/bash

#
# Frame rate for encode call later.
#
frame_rate=24

function usage() {
  echo "Usage: `basename $0` [hour-of-day]"
}

if [ $# -gt 1 ]; then
  usage
  exit 1
fi

#
# Base directory.
#
upload_host=gaspberrypi.fritz.box
upload_user=pi
img_base_dir=/var/lib/tomcat8/webapps/svc/img
dest_dir=${img_base_dir}

#
# Handle optional input parameter hour-of-day.
#
if [ $# -eq 1 ]; then
  hour_of_day=$1
else
  hour_of_day=$( date '+%H' )
fi

#
# Work from image directory (easier)
#
cd ${img_base_dir}
if [ $? -ne 0 ]; then
  echo "Could not change directory to ${img_base_dir}, exiting."
  exit 1
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

day=`date '+%d'`

#
# Use bash arithmetic context for calculations.
#
if [ $# -eq 1 ]; then
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

echo "Using day=${day}, previous hour=${previous_hour}"

#
# Build directory name for encode call later.
#
img_directory=$( printf '%04d/%02d/%02d/%02d' ${year} ${raw_month#0} ${day#0} ${previous_hour#0} )

#
# Build search pattern for selecting images to copy.
#
pattern=$( printf 'r_%d%02d%02d' ${month#0} ${day#0} ${previous_hour#0} )

echo "Matching ${pattern}*"
echo "Copying $( ls ${img_base_dir}/${pattern}* | wc -l ) files."

echo "Copying images to upload host ${upload_host}:${dest_dir}"
scp -p ${pattern}* ${upload_user}'@'${upload_host}:${dest_dir}
ret=$?

if [ $ret -ne 0 ]; then
  echo "Could not copy images to upload host."
  exit 2
else
  echo "Removing images matching pattern ${pattern}*.jpg after successfull copy."
  rm ${pattern}*.jpg
fi

echo "`date`: Copy completed, running archive on upload host..."
echo "ssh ${upload_user}'@'${upload_host} svc/bin/run_archive.sh ${pattern}* "

ssh ${upload_user}'@'${upload_host} svc/bin/run_archive.sh ${pattern}*
ret=$?
if [ $ret -ne 0 ]; then
  echo "Uploading of images failed ($ret)."
  exit 1
fi

echo "ssh ${upload_user}'@'${upload_host} svc/bin/run_encode.sh ${img_directory} ${frame_rate}"
ssh ${upload_user}'@'${upload_host} svc/bin/run_encode.sh ${img_directory} ${frame_rate}
