#!/bin/bash

#
# Frame rate for encode call later.
#
frame_rate=24

function usage() {
  echo "Usage: `basename $0` day hour-of-day"
}

if [ $# -ne 2 ]; then
  usage
  exit 1
fi

#
# Base directory.
#
upload_host=raspberry.fritz.box
upload_user=pi
img_base_dir=/var/images
src_dir=${img_base_dir}
dest_dir=/home/pi/images/raspi2

#
# Handle input parameters day and hour-of-day.
#

day=$1
hour_of_day=$2

#
# Work from image directory (easier)
#
cd ${src_dir}
if [ $? -ne 0 ]; then
  echo "Could not change directory to ${src_dir}, exiting."
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

# day=`date '+%d'`
previous_hour=${hour_of_day}

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
  rm -f ${pattern}*.jpg
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
