#!/bin/sh
cat userdisk/appdata/app_infos/2882303761517280984.manifest |grep status|awk -F \" '{print $2}'
