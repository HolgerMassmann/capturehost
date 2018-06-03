#!/bin/bash
img_dir=/home/pi/svc_web/img
ls ${img_dir} | cut -c1-5 | sort -u | grep -v late
