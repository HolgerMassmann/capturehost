#!/bin/sh

imgdir=/var/lib/tomcat8/webapps/svc/img
latest=/run/images/latest.jpg

usage() {
  echo "`basename $0` delay width height prefix imgdir"
}


if [ $# -ne 5 ]; then
  usage
  exit 0
fi

delayms=$1
shift

width=$1
shift

height=$1
shift

prefix=$1
shift

imgdir=$1
shift

echo "Going to execute raspistill -n -hf -vf -t 0 -tl ${delayms} -o ${imgdir}/${prefix}%d.jpg -dt -w ${width} -h ${height} -l latest.jpg -a 12 -ae 16 &"

raspistill -n -hf -vf -t 0 -tl ${delayms} -o ${imgdir}/${prefix}%d.jpg -dt -w ${width} -h ${height} -l ${latest} -a 12 -ae 16 &

