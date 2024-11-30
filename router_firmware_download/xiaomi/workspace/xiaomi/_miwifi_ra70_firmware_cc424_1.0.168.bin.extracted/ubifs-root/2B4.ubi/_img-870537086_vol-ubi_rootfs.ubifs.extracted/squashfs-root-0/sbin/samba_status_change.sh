#!/bin/sh

api=$1
appid=$2
status=$3
if [ "$api" != "1108" ];then
	exit
fi

if [ "$status" == "5" ];then
	curl http://localhost/api-third-party/service/datacenter/plugin_enable?appId=$appid
fi

if [ "$status" == "6" ];then
        curl http://localhost/api-third-party/service/datacenter/plugin_disable?appId=$appid
fi
