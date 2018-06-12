#!/bin/bash
img_dir=/var/lib/tomcat8/webapps/svc/img
ls ${img_dir} | cut -c1-7 | sort -u | grep -v latest
