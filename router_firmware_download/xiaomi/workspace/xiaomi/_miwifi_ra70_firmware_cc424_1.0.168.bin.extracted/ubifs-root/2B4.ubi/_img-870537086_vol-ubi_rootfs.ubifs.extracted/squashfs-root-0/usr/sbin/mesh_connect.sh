#!/bin/sh
# Copyright (C) 2020 Xiaomi

. /lib/mimesh/mimesh_public.sh
. /lib/mimesh/mimesh_stat.sh
. /lib/mimesh/mimesh_init.sh

#bhdev="game" #instead of 5G
bh_tag=$(uci -q get misc.backhauls.backhaul)
[ -z "$bh_tag" ] && bh_tag="$BHTAG"
BHDEV=$(echo $bh_tag | sed 'y/aegm/AEGM/')

log(){
	logger -t "meshd connect: " -p9 "$1"
}
check_re_initted(){
	initted=$(uci -q get xiaoqiang.common.INITTED)
	[ "$initted" == "YES" ] && { log "RE already initted. exit 0." ; exit 0; }
}
run_with_lock(){
	{
		log "$$, ====== TRY locking......"
		flock -x -w 60 1000
		[ $? -eq "1" ] && { log "$$, ===== GET lock failed. exit 1" ; exit 1 ; }
		log "$$, ====== GET lock to RUN."
		$@
		log "$$, ====== END lock to RUN."
	} 1000<>/var/log/mesh_connect_lock.lock
}
usage() {
	echo "$0 re_start xx:xx:xx:xx:xx:xx"
	echo "$0 help"
	exit 1
}

eth_down() {
	local ifnames=$(uci -q get network.lan.ifname)
	local wan_ifname=$(uci -q get network.wan.ifname)
	for if_name in $ifnames
	do
		ifconfig $if_name down
	done
	ifconfig $wan_ifname down
}

eth_up() {
	local ifnames=$(uci -q get network.lan.ifname)
	local wan_ifname=$(uci -q get network.wan.ifname)
	for if_name in $ifnames
	do
		ifconfig $if_name up
	done
	ifconfig $wan_ifname up
}

set_network_id() {
	local bh_ssid=$1
	local pre_id=$(uci -q get xiaoqiang.common.NETWORK_ID)
	local new_id=$(echo "$bh_ssid" | md5sum | cut -c 1-8)
	if [ -z "$pre_id" -o "$pre_id" != "$new_id" ]; then
		uci set xiaoqiang.common.NETWORK_ID="$new_id"
		uci commit xiaoqiang
	fi
}

cap_close_wps() {
	local ifname=$(uci -q get misc.wireless.ifname_${BHTAG})
	local device=$(uci -q get misc.wireless.if_${BHTAG})
	hostapd_cli -i $ifname -p /var/run/hostapd-${device} -P /var/run/hostapd_cli-${ifname}.pid wps_cancel
	iwpriv $ifname miwifi_mesh 3
	hostapd_cli -i $ifname -p /var/run/hostapd-${device} -P /var/run/hostapd_cli-${ifname}.pid update_beacon
}

cap_disable_wps_trigger() {
	local ifname=$2
	local device=$1

	#uci set wireless.@wifi-iface[1].miwifi_mesh=3
	#uci commit wireless

	iwpriv $ifname miwifi_mesh 3
	hostapd_cli -i $ifname -p /var/run/hostapd-${device} -P /var/run/hostapd_cli-${ifname}.pid update_beacon
}

wpa_supplicant_if_add() {
	local ifname=$1
	local bridge=$2
	local driver="nl80211"

	[ -f "/var/run/wpa_supplicant-$ifname.lock" ] && rm /var/run/wpa_supplicant-$ifname.lock
	wpa_cli -g /var/run/wpa_supplicantglobal interface_add  $ifname /var/run/wpa_supplicant-$ifname.conf $driver /var/run/wpa_supplicant-$ifname "" $bridge
	touch /var/run/wpa_supplicant-$ifname.lock
}

wpa_supplicant_if_remove() {
	local ifname=$1

	[ -f "/var/run/wpa_supplicant-${ifname}.lock" ] && { \
		wpa_cli -g /var/run/wpa_supplicantglobal  interface_remove  ${ifname}
		rm /var/run/wpa_supplicant-${ifname}.lock
	}
}

re_clean_vap() {
	local ifname=$(uci -q get misc.wireless.apclient_${BHDEV})

	wpa_supplicant_if_remove $ifname
	wlanconfig $ifname destroy -cfg80211

	local lanip=$(uci -q get network.lan.ipaddr)
	if [ "$lanip" != "" ]; then
		ifconfig br-lan $lanip
	else
		ifconfig br-lan 192.168.31.1
	fi

	eth_up
	wifi
}

check_re_init_status_v2() {
	for i in $(seq 1 60)
	do
		mimesh_re_assoc_check > /dev/null 2>&1
		[ $? = 0 ] && break
		sleep 2
	done

	mimesh_init_done "re"
	/etc/init.d/meshd stop
	eth_up
}

do_re_init() {
	#check if re initted to avoid re-enter
	check_re_initted
	log "=== do_re_init start......."

	local ifname=$(uci -q get misc.wireless.apclient_${BHDEV})

	local ssid_2g="$1"
	local pswd_2g=""
	local mgmt_2g=$3
	[ "$mgmt_2g" = "none" ] || pswd_2g="$2"
	local ssid_5g=""
	local pswd_5g=""
	local mgmt_5g=""
	local nbh_b64=""
	#[ "$mgmt_5g" = "none" ] || pswd_5g="$5"
	local bh_ssid=$(base64_dec $7)
	local bh_pswd=$(base64_dec $8)
	local bh_mgmt=$9

	local ssid_game=""
	local pswd_game=""
	local mgmt_game=""
	#[ "$mgmt_game" = "none" ] || pswd_game="$5"
	local bsd=""

	local bh_band=""
	local iface_5g_swap=""

	set_network_id "$bh_ssid"

	wpa_supplicant_if_remove $ifname
	wlanconfig $ifname destroy -cfg80211

	touch /tmp/bh_maclist_5g
	#touch /tmp/bh_maclist_2g
	local bh_maclist_5g=$(cat /tmp/bh_maclist_5g | sed 's/ /,/g')
	#local bh_maclist_2g=$(cat /tmp/bh_maclist_2g | sed 's/ /,/g')
	local bh_macnum_5g=$(echo $bh_maclist_5g | awk -F"," '{print NF}')
	#local bh_macnum_2g=$(echo $bh_maclist_2g | awk -F"," '{print NF}')

	do_re_init_json
	log "do_re_init bh_band:$bh_band, iface_5g_swap:$iface_5g_swap, ssid:$4, mgmt:$6"
	if [ "$bh_tag" == "$BHTAG" ]; then # cap bh radio was work on 5g low band (band 1/2)
		if [ "$iface_5g_swap" != "1" ]; then
			ssid_game="$4"
			mgmt_game="$6"
			[ "$mgmt_game" = "none" ] || pswd_game="$5"
		else
			ssid_5g="$4"
			mgmt_5g="$6"
			[ "$mgmt_5g" = "none" ] || pswd_5g="$5"
		fi
		if [ -z "$ssid_5g" ]; then # cap is not AX9000
			ssid_5g=${ssid_game}
			pswd_5g=${pswd_game}
			mgmt_5g=${mgmt_game}
		fi
	else # cap bh radio was work on 5g high band (band 3/4)
		if [ "$iface_5g_swap" != "1" ]; then
			ssid_5g="$4"
			mgmt_5g="$6"
			[ "$mgmt_5g" = "none" ] || pswd_5g="$5"
		else
			ssid_game="$4"
			mgmt_game="$6"
			[ "$mgmt_game" = "none" ] || pswd_game="$5"
		fi
		if [ -z "$ssid_game" ]; then # cap is not AX9000
			ssid_game=${ssid_5g}
			pswd_game=${pswd_5g}
			mgmt_game=${mgmt_5g}
		fi
	fi

	local buff="{\"method\":\"init\",\"params\":{\"whc_role\":\"RE\",\"bsd\":\"${bsd}\",\"ssid_2g\":\"${ssid_2g}\",\"pswd_2g\":\"${pswd_2g}\",\"mgmt_2g\":\"${mgmt_2g}\",\"ssid_5g\":\"${ssid_5g}\",\"pswd_5g\":\"${pswd_5g}\",\"mgmt_5g\":\"${mgmt_5g}\",\"bh_ssid\":\"${bh_ssid}\",\"bh_pswd\":\"${bh_pswd}\",\"bh_mgmt\":\"${bh_mgmt}\",\"bh_macnum_5g\":\"${bh_macnum_5g}\",\"bh_maclist_5g\":\"${bh_maclist_5g}\",\"bh_macnum_2g\":\"0\",\"bh_maclist_2g\":\"\", \"ssid_game\":\"${ssid_game}\",\"pswd_game\":\"${pswd_game}\",\"mgmt_game\":\"$mgmt_game\"}}"

	mimesh_init "$buff" "$10"
	sleep 2
	check_re_init_status_v2
}

do_re_init_bsd() {
	local ifname=$(uci -q get misc.wireless.apclient_${BHDEV})

	local whc_ssid="$1"
	local whc_pswd=
	local whc_mgmt=$3
	[ "$whc_mgmt" = "none" ] || whc_pswd="$2"
	local bh_ssid=$(base64_dec $4)
	local bh_pswd=$(base64_dec $5)
	local bh_mgmt=$6

	local ssid_5g=""
	local pswd_5g=""
	local mgmt_5g=""
	local bsd=""
	local bh_band=""
	local iface_5g_swap=""
	#local ssid=$(grep "ssid=\"" /var/run/wpa_supplicant-${ifname}.conf | awk -F\" '{print $2}')
	#local key=$(grep "psk=\"" /var/run/wpa_supplicant-${ifname}.conf | awk -F\" '{print $2}')

	set_network_id "$bh_ssid"

	wpa_supplicant_if_remove $ifname
	wlanconfig $ifname destroy -cfg80211

	touch /tmp/bh_maclist_5g
	#touch /tmp/bh_maclist_2g
	local bh_maclist_5g=$(cat /tmp/bh_maclist_5g | sed 's/ /,/g')
	#local bh_maclist_2g=$(cat /tmp/bh_maclist_2g | sed 's/ /,/g')
	local bh_macnum_5g=$(echo $bh_maclist_5g | awk -F"," '{print NF}')
	#local bh_macnum_2g=$(echo $bh_maclist_2g | awk -F"," '{print NF}')

	do_re_init_json
	if [ "$bh_tag" = "$BHTAG" ]; then # cap bh radio was work on 5g low band (band 1/2)
		if [ -z "$ssid_5g" ]; then # cap is not AX9000
			ssid_5g=${whc_ssid}
			pswd_5g=${whc_pswd}
			mgmt_5g=${whc_mgmt}
			bsd="1"  # Here, need set bsd to "1"
		fi
	else # cap bh radio was work on 5g high band (band 3/4)
		if [ -z "$ssid_game" ]; then # cap is not AX9000
			ssid_game=${whc_ssid}
			pswd_game=${whc_pswd}
			mgmt_game=${whc_mgmt}
			bsd="1"  # Here, need set bsd to "1"
		fi
	fi

	local buff="{\"method\":\"init\",\"params\":{\"whc_role\":\"RE\",\"bsd\":\"${bsd}\",\"whc_ssid\":\"${whc_ssid}\",\"whc_pswd\":\"${whc_pswd}\",\"whc_mgmt\":\"${whc_mgmt}\",\"bh_ssid\":\"${bh_ssid}\",\"bh_pswd\":\"${bh_pswd}\",\"bh_mgmt\":\"${bh_mgmt}\",\"bh_macnum_5g\":\"${bh_macnum_5g}\",\"bh_maclist_5g\":\"${bh_maclist_5g}\",\"bh_macnum_2g\":\"0\",\"bh_maclist_2g\":\"\",\"ssid_game\":\"${whc_ssid}\",\"pswd_game\":\"${whc_pswd}\",\"mgmt_game\":\"${whc_mgmt}\"}}"

	mimesh_init "$buff" "$7"
	sleep 2
	check_re_init_status_v2
}

do_re_init_json() {
	local jsonbuf=$(cat /tmp/extra_wifi_param 2>/dev/null)
	[ -z "$jsonbuf" ] && return

	#set max mesh version we can support
	local version_list=$(uci -q get misc.mesh.version)
	if [ -z "$version_list" ]; then
		log "version list is empty"
		return
	fi

	local max_version=1
	for version in $version_list; do
		if [ $version -gt $max_version ]; then
			max_version=$version
		fi
	done

	uci set xiaoqiang.common.MESH_VERSION="$max_version"
	uci commit

	local device_2g=$(uci -q get misc.wireless.if_2G)
	local device_5g=$(uci -q get misc.wireless.if_5G)
	local device_game=$(uci -q get misc.wireless.if_game)
	local ifname_2g=$(uci -q get misc.wireless.ifname_2G)
	local ifname_5g=$(uci -q get misc.wireless.ifname_5G)
	local ifname_game=$(uci -q get misc.wireless.ifname_game)

	# for RB08 CAP-9000 RE, need to check whether swap game/5gh iface cfg
	bh_band=$(json_get_value "$jsonbuf" "bh_band")
	iface_5g_swap=$(json_get_value "$jsonbuf" "iface_5g_swap")
	[ -z "$iface_5g_swap" ] && iface_5g_swap=0
	[ "$bh_band" = "5gh" ] && {
		log "=== do_re_init_json bh_band:$bh_band, change bh to $BHTAG_SEC"
		bh_tag=$BHTAG_SEC
		uci -q set misc.backhauls.backhaul="$BHTAG_SEC"
		uci commit misc
	}

	# for 9000, for game radio was bh radio, game radio use 5g cfg and 5g radio use 5g_nbh cfg
	local suffix_5g="5g_nbh"
	local suffix_game="5g"
	[ "$bh_tag" != "$BHTAG" ] && {
		suffix_5g="5g"
		suffix_game="5g_nbh"
	}

	# wifi-iface options
	local hidden_2g=$(json_get_value "$jsonbuf" "hidden_2g")
	local hidden_5g=$(json_get_value "$jsonbuf" "hidden_${suffix_5g}")
	local hidden_game=$(json_get_value "$jsonbuf" "hidden_${suffix_game}")
	[ "$iface_5g_swap" = "1" ] && {
		hidden_5g=$(json_get_value "$jsonbuf" "hidden_${suffix_game}")
		hidden_game=$(json_get_value "$jsonbuf" "hidden_${suffix_5g}")
	}
	local disabled_2g=$(json_get_value "$jsonbuf" "disabled_2g")
	local disabled_5g=$(json_get_value "$jsonbuf" "disabled_${suffix_5g}")
	local disabled_game=$(json_get_value "$jsonbuf" "disabled_${suffix_game}")
	[ "$iface_5g_swap" = "1" ] && {
		disabled_5g=$(json_get_value "$jsonbuf" "disabled_${suffix_game}")
		disabled_game=$(json_get_value "$jsonbuf" "disabled_${suffix_5g}")
	}

	# wifi-device options
	local ax_2g=$(json_get_value "$jsonbuf" "ax_2g")
	local ax_5g=$(json_get_value "$jsonbuf" "ax_${suffix_5g}")
	local ax_game=$(json_get_value "$jsonbuf" "ax_${suffix_game}")
	local txpwr_2g=$(json_get_value "$jsonbuf" "txpwr_2g")
	local txpwr_5g=$(json_get_value "$jsonbuf" "txpwr_${suffix_5g}")
	local txpwr_game=$(json_get_value "$jsonbuf" "txpwr_${suffix_game}")
	local bw_2g=$(json_get_value "$jsonbuf" "bw_2g")
	local bw_5g=$(json_get_value "$jsonbuf" "bw_${suffix_5g}")
	local bw_game=$(json_get_value "$jsonbuf" "bw_${suffix_game}")
	local txbf_2g=$(json_get_value "$jsonbuf" "txbf_2g")
	local txbf_5g=$(json_get_value "$jsonbuf" "txbf_${suffix_5g}")
	local txbf_game=$(json_get_value "$jsonbuf" "txbf_${suffix_game}")
	local ch_2g=$(json_get_value "$jsonbuf" "ch_2g")
	local ch_5g=$(json_get_value "$jsonbuf" "ch_${suffix_5g}")
	local ch_game=$(json_get_value "$jsonbuf" "ch_${suffix_game}")
	local web_passwd=$(json_get_value "$jsonbuf" "web_passwd")
	local policy=$(json_get_value "$jsonbuf" "policy")
	local maclist=$(json_get_value "$jsonbuf" "maclist")
	local maclist_format="`echo -n $maclist | sed "s/;/ /g"`"
	local support160=$(json_get_value "$jsonbuf" "support160")

	[ "$ch_game" != "auto" -a "$ch_game" -gt 48 ] && ch_game="auto"

	local cap_is_dual_band=0
	if [ "$bh_tag" = "$BHTAG" ]; then
		log "bh use game radio"
		[ -z $ch_5g ] && { # CAP is daul-band device
			log "CAP is dual band device"
			cap_is_dual_band=1
			hidden_5g=$hidden_game
			disabled_5g=$disabled_game
			ax_5g=$ax_game
			txpwr_5g=$txpwr_game
			txbf_5g=$txbf_game
			ch_5g=149
			bw_5g=0
		}
	else
		log "bh use 5g radio"
		[ -z $ch_game ] && { # CAP is daul-band device
			log "CAP is dual band device"
			cap_is_dual_band=1
			hidden_game=$hidden_5g
			disabled_game=$disabled_5g
			ax_game=$ax_5g
			txpwr_game=$txpwr_5g
			txbf_game=$txbf_5g
			ch_game=36
			bw_game=0
		}
	fi

	uci set wireless.$device_2g.channel="$ch_2g"
	uci set wireless.$device_5g.channel="$ch_5g"
	uci set wireless.$device_game.channel="$ch_game"

	uci set wireless.$device_2g.ax="$ax_2g"
	uci set wireless.$device_5g.ax="$ax_5g"
	uci set wireless.$device_game.ax="$ax_game"

	uci set wireless.$device_2g.txpwr="$txpwr_2g"
	uci set wireless.$device_5g.txpwr="$txpwr_5g"
	uci set wireless.$device_game.txpwr="$txpwr_game"

	uci set wireless.$device_2g.txbf="$txbf_2g"
	uci set wireless.$device_5g.txbf="$txbf_5g"
	uci set wireless.$device_game.txbf="$txbf_game"

	uci set wireless.$device_2g.bw="$bw_2g"
	uci set wireless.$device_5g.bw="$bw_5g"
	[ -z $bw_game ] && bw_game=0
	if [ "$bh_tag" = "$BHTAG" ] && [ "$support160" != "1" ] && [ "$bw_game" = "0" ]; then
		bw_game=80
	fi
	uci set wireless.$device_game.bw="$bw_game"

	local iface_2g=$(uci show wireless | grep -w "ifname=\'$ifname_2g\'" | awk -F"." '{print $2}')
	local iface_5g=$(uci show wireless | grep -w "ifname=\'$ifname_5g\'" | awk -F"." '{print $2}')

	uci set wireless.$iface_2g.hidden="$hidden_2g"
	uci set wireless.$iface_5g.hidden="$hidden_5g"
	uci set wireless.$iface_game.hidden="$hidden_game"
	
	uci set wireless.$iface_2g.disabled="0"
	uci set wireless.$iface_5g.disabled="0"
	uci set wireless.$iface_game.disabled="0"

	if [ -n "$web_passwd" ]; then
		uci set account.common.admin="$web_passwd"
		uci commit account
	fi

	if [ -n "$policy" ]; then
		uci set wireless.$iface_2g.macfilter="$policy"
		uci set wireless.$iface_5g.macfilter="$policy"
		uci set wireless.$iface_game.macfilter="$policy"
	fi
	for mac in $maclist_format; do
		uci add_list wireless.$iface_2g.maclist="$mac"
		uci add_list wireless.$iface_5g.maclist="$mac"
		uci add_list wireless.$iface_game.maclist="$mac"
	done

	uci commit wireless

	#cap_mode
	local cap_mode=$(json_get_value "$jsonbuf" "cap_mode")
	uci set xiaoqiang.common.CAP_MODE="$cap_mode"

	local cap_ip=$(json_get_value "$jsonbuf" "cap_ip")
	[ -n "$cap_ip" ] && uci -q set xiaoqiang.common.CAP_IP="$cap_ip"

	if [ "$cap_mode" = "ap" ]; then
		local vendorinfo=$(json_get_value "$jsonbuf" "vendorinfo")
		uci set xiaoqiang.common.vendorinfo="$vendorinfo"
	fi
	[ $cap_is_dual_band -eq 1 ] && uci set xiaoqiang.common.CAP_IS_DUAL_BAND='1'
	uci commit xiaoqiang

	bsd=$(json_get_value "$jsonbuf" "bsd")
	nbh_b64=$(json_get_value "$jsonbuf" "nbh_b64")

	if [ "$bh_tag" = "$BHTAG" ]; then
		if [ "$iface_5g_swap" != "1" ]; then
			ssid_5g=$(json_get_value "$jsonbuf" "ssid_${suffix_5g}")
			pswd_5g=$(json_get_value "$jsonbuf" "pswd_${suffix_5g}")
			mgmt_5g=$(json_get_value "$jsonbuf" "mgmt_${suffix_5g}")
		else
			ssid_5g=$(json_get_value "$jsonbuf" "ssid_${suffix_game}")
			pswd_5g=$(json_get_value "$jsonbuf" "pswd_${suffix_game}")
			mgmt_5g=$(json_get_value "$jsonbuf" "mgmt_${suffix_game}")
		fi
		if [ "$nbh_b64" != "1" ]; then
			ssid_5g=$(base64_enc $ssid_5g)
			pswd_5g=$(base64_enc $pswd_5g)
		fi
	else
		if [ "$iface_5g_swap" != "1" ]; then
			ssid_game=$(json_get_value "$jsonbuf" "ssid_${suffix_game}")
			pswd_game=$(json_get_value "$jsonbuf" "pswd_${suffix_game}")
			mgmt_game=$(json_get_value "$jsonbuf" "mgmt_${suffix_game}")
		else
			ssid_game=$(json_get_value "$jsonbuf" "ssid_${suffix_5g}")
			pswd_game=$(json_get_value "$jsonbuf" "pswd_${suffix_5g}")
			mgmt_game=$(json_get_value "$jsonbuf" "mgmt_${suffix_5g}")
		fi
		if [ "$nbh_b64" != "1" ]; then
			ssid_game=$(base64_enc $ssid_game)
			pswd_game=$(base64_enc $pswd_game)
		fi
	fi
}

init_cap_mode() {
	local ifname_5g=$(uci -q get misc.wireless.ifname_${bh_tag})
	local iface_5g=$(uci show wireless | grep -w "ifname=\'$ifname_5g\'" | awk -F"." '{print $2}')
	local ifname_5g_nbh=$(uci -q get misc.wireless.ifname_5G)
	[ "$bh_tag" = "$BHTAG_SEC" ] && {
		ifname_5g_nbh=$(uci -q get misc.wireless.ifname_${BHTAG})
	}
	local iface_5g_nbh=$(uci show wireless | grep -w "ifname=\'$ifname_5g_nbh\'" | awk -F"." '{print $2}')
	/etc/init.d/meshd stop
	uci set wireless.$iface_5g.miwifi_mesh=0
	uci set wireless.$iface_5g_nbh.miwifi_mesh=0
	uci commit wireless
}

cap_delete_vap() {
	local ifname=$(uci -q get misc.wireless.mesh_ifname_5G)

	local hostapd_pid=$(ps | grep "hostapd\ /var/run/hostapd-${ifname}.conf" | awk '{print $1}')

	[ -z "$hostapd_pid" ] || kill -9 $hostapd_pid

	rm -f /var/run/hostapd-${ifname}.conf
	wlanconfig $ifname destroy -cfg80211
}

cap_clean_vap() {
	local ifname=$1
	local name=$(echo $2 | sed s/[:]//g)
	cap_delete_vap
	echo "failed" > /tmp/${name}-status
}

check_cap_init_status_v2() {
	local ifname=$(uci -q get misc.backhauls.backhaul_${bh_tag}_ap_iface)
	local device_5g=$(uci -q get misc.wireless.if_${bhdev})
	[ "$bh_tag" = "$BHTAG_SEC" ] && {
		device_5g=$(uci -q get misc.wireless.if_${BHDEV})
	}
	local re_5g_mac=$2
	local is_cable=$5
	[ -z "$is_cable" ] && is_cable=0

	for i in $(seq 1 60)
	do
		mimesh_cap_bh_check > /dev/null 2>&1
		if [ $? = 0 ]; then
			mimesh_init_done "cap"
			sleep 2
			init_done=1
			break
		fi
		sleep 2
	done

	if [ $init_done -eq 1 ]; then
		for i in $(seq 1 120)
		do
			local assoc_count1=$(iwinfo $ifname a | grep -i -c $3)
			local assoc_count2=$(iwinfo $ifname a | grep -i -c $4)
			local assoc_count3=0
			if [ $(expr $i % 5) -eq 0 ]; then
				assoc_count3=$(ubus call trafficd hw | grep -iwc $re_5g_mac)
			fi

            #check by mosquitto connections
            local mac1=$3
            local mac2=$4
            mac1="${mac1//:/}"
            mac2="${mac2//:/}"
            local assoc_count4=$(egrep -ic "$mac1|$mac2" /tmp/mosquitto_clients.dump)
            [ -z "$assoc_count4" ] && assoc_count4=0
            echo "check_cap_init_status: assoc_count1: $assoc_count1,assoc_count2: $assoc_count2,assoc_count3: $assoc_count3,assoc_count4: $assoc_count4" >/dev/console
			if [ $assoc_count4 -gt 0 -o $assoc_count1 -gt 0 -o $assoc_count2 -gt 0 -o $assoc_count3 -gt 0 ]; then
				/sbin/cap_push_backhaul_whitelist.sh
				(sleep 30; /sbin/cap_push_backhaul_whitelist.sh) &
				/usr/sbin/topomon_action.sh cap_init
				echo "success" > /tmp/$1-status
				radartool -i $device_5g enable
				exit 0
			fi
			sleep 2
		done
	fi

	echo "failed" > /tmp/$1-status
	radartool -i $device_5g enable
	exit 1
}

do_cap_init_bsd() {
	local name=$(echo $1 | sed s/[:]//g)
	local is_cable=$8
	[ -z "$is_cable" ] && is_cable=0

	local ifname_ap_2g=$(uci -q get misc.wireless.ifname_2G)
	local iface_2g=$(uci show wireless | grep -w "ifname=\'$ifname_ap_2g\'" | awk -F"." '{print $2}')
	local ifname_ap_game=$(uci -q get misc.wireless.ifname_game)
	local iface_game=$(uci show wireless | grep -w "ifname=\'$ifname_ap_game\'" | awk -F"." '{print $2}')

	local whc_ssid=$(uci -q get wireless.$iface_2g.ssid)
	local whc_pswd=$(uci -q get wireless.$iface_2g.key)
	local whc_mgmt=$(uci -q get wireless.$iface_2g.encryption)

	#local ssid_game=$(uci -q get wireless.$iface_game.ssid)
	#local pswd_game=$(uci -q get wireless.$iface_game.key)
	#local mgmt_game=$(uci -q get wireless.$iface_game.encryption)

	local ifname_5g=$(uci -q get misc.backhauls.backhaul_${bh_tag}_ap_iface)

	local bh_ssid=$(base64_dec $6)
	local bh_pswd=$(base64_dec $7)
	local init_done=0

	local device_5g=$(uci -q get misc.wireless.if_${bh_tag})
	[ "$bh_tag" = "$BHTAG_SEC" ] && {
		device_5g=$(uci -q get misc.wireless.if_${BHDEV})
	}

	local channel=$(uci -q get wireless.$device_5g.channel)
	local bw=$(uci -q get wireless.$device_5g.bw)
	local bsd=$(uci -q get wireless.$iface_2g.bsd)

	#local re_bssid=$1
	#local obssid_jsonbuf=$(cat /var/run/scanrelist | grep -i "$re_bssid")
	#local re_mesh_ver=$(json_get_value "$obssid_jsonbuf" "mesh_ver")
	#[ -z "$re_mesh_ver" ] && re_mesh_ver=2

	echo "syncd" > /tmp/${name}-status

	set_network_id "$bh_ssid"

	cap_delete_vap

	local mode=$(uci -q get xiaoqiang.common.NETMODE)
	local cap_mode=$(uci -q get xiaoqiang.common.CAP_MODE)
	if [ "whc_cap" != "$mode" ] && [ "$mode" != "lanapmode" -o "$cap_mode" != "ap" ]; then
		local bh_maclist_5g=
		local bh_macnum_5g=0

		if [ "$whc_mgmt" == "ccmp" ]; then
			whc_pswd=$(uci -q get wireless.$iface_2g.sae_password)
		fi

		#if [ "$mgmt_game" == "ccmp" ]; then
		#	pswd_game=$(uci -q get wireless.$iface_game.sae_password)
		#fi

		whc_ssid=$(base64_enc "$whc_ssid")
		whc_pswd=$(base64_enc "$whc_pswd")

		case "$channel" in
			52|56|60|64|100|104|108|112|116|120|124|128|132|136|140|149|153|157|161|165)
				if [ "$bw" -eq 0 ]; then
					uci set wireless.$device_5g.channel='36'
				else
					uci set wireless.$device_5g.channel='auto'
				fi
				uci commit wireless
				;;
			*) ;;
		esac

		#ignore CAC on first init
		radartool -i $device_5g disable

		local buff="{\"method\":\"init\",\"params\":{\"whc_role\":\"CAP\",\"bsd\":\"${bsd}\",\"whc_ssid\":\"${whc_ssid}\",\"whc_pswd\":\"${whc_pswd}\",\"whc_mgmt\":\"${whc_mgmt}\",\"bh_ssid\":\"${bh_ssid}\",\"bh_pswd\":\"${bh_pswd}\",\"bh_mgmt\":\"psk2\",\"bh_macnum_5g\":\"${bh_macnum_5g}\",\"bh_maclist_5g\":\"${bh_maclist_5g}\",\"bh_macnum_2g\":\"0\",\"bh_maclist_2g\":\"\",\"ssid_game\":\"${whc_ssid}\",\"pswd_game\":\"${whc_pswd}\",\"mgmt_game\":\"${whc_mgmt}\"}}"

		mimesh_init "$buff"
	fi

	check_cap_init_status_v2 $name $1 $3 $5 $is_cable
}

do_cap_init() {
	log "=== do_cap_init start......."
	local name=$(echo $1 | sed s/[:]//g)
	local is_cable=$8
	[ -z "$is_cable" ] && is_cable=0

	local ifname_ap_2g=$(uci -q get misc.wireless.ifname_2G)
	local iface_2g=$(uci show wireless | grep -w "ifname=\'$ifname_ap_2g\'" | awk -F"." '{print $2}')
	local ifname_ap_5g=$(uci -q get misc.wireless.ifname_5G)
	local iface_5g=$(uci show wireless | grep -w "ifname=\'$ifname_ap_5g\'" | awk -F"." '{print $2}')
	local ifname_ap_game=$(uci -q get misc.wireless.ifname_game)
	local iface_game=$(uci show wireless | grep -w "ifname=\'$ifname_ap_game\'" | awk -F"." '{print $2}')
	local device_5g=$(uci -q get misc.wireless.if_${bh_tag})
	[ "$bh_tag" = "$BHTAG_SEC" ] && {
		device_5g=$(uci -q get misc.wireless.if_${BHDEV})
	}

	local ssid_2g=$(uci -q get wireless.$iface_2g.ssid)
	local pswd_2g=$(uci -q get wireless.$iface_2g.key)
	local mgmt_2g=$(uci -q get wireless.$iface_2g.encryption)
	local ssid_5g=$(uci -q get wireless.$iface_5g.ssid)
	local pswd_5g=$(uci -q get wireless.$iface_5g.key)
	local mgmt_5g=$(uci -q get wireless.$iface_5g.encryption)
	local ssid_game=$(uci -q get wireless.$iface_game.ssid)
	local pswd_game=$(uci -q get wireless.$iface_game.key)
	local mgmt_game=$(uci -q get wireless.$iface_game.encryption)

	local ifname_5g=$(uci -q get misc.backhauls.backhaul_${bh_tag}_ap_iface)

	local bh_ssid=$(base64_dec $6)
	local bh_pswd=$(base64_dec $7)
	local init_done=0

	local channel=$(uci -q get wireless.$device_5g.channel)
	local bw=$(uci -q get wireless.$device_5g.bw)
	local bsd=$(uci -q get wireless.$iface_2g.bsd)

	#local re_bssid=$1
	#local obssid_jsonbuf=$(cat /var/run/scanrelist | grep -i "$re_bssid")
	#local re_mesh_ver=$(json_get_value "$obssid_jsonbuf" "mesh_ver")
	#[ -z "$re_mesh_ver" ] && re_mesh_ver=2

	echo "syncd" > /tmp/${name}-status

	set_network_id "$bh_ssid"

	cap_delete_vap

	local mode=$(uci -q get xiaoqiang.common.NETMODE)
	local cap_mode=$(uci -q get xiaoqiang.common.CAP_MODE)
	if [ "whc_cap" != "$mode" ] && [ "$mode" != "lanapmode" -o "$cap_mode" != "ap" ]; then
		local bh_maclist_5g=
		local bh_macnum_5g=0

		if [ "$mgmt_2g" == "ccmp" ]; then
			pswd_2g=$(uci -q get wireless.$iface_2g.sae_password)
		fi

		if [ "$mgmt_5g" == "ccmp" ]; then
			pswd_5g=$(uci -q get wireless.$iface_5g.sae_password)
		fi

		if [ "$mgmt_game" == "ccmp" ]; then
			pswd_game=$(uci -q get wireless.$iface_game.sae_password)
		fi

		ssid_2g=$(base64_enc "$ssid_2g")
		pswd_2g=$(base64_enc "$pswd_2g")
		ssid_5g=$(base64_enc "$ssid_5g")
		pswd_5g=$(base64_enc "$pswd_5g")
		ssid_game=$(base64_enc "$ssid_game")
		pswd_game=$(base64_enc "$pswd_game")

		case "$channel" in
			52|56|60|64|100|104|108|112|116|120|124|128|132|136|140|149|153|157|161|165)
				if [ "$bw" -eq 0 ]; then
					uci set wireless.$device_5g.channel='36'
				else
					uci set wireless.$device_5g.channel='auto'
				fi
				uci commit wireless
				;;
			*) ;;
		esac

		#ignore CAC on first init
		radartool -i $device_5g disable

		local buff="{\"method\":\"init\",\"params\":{\"whc_role\":\"CAP\",\"bsd\":\"${bsd}\",\"ssid_2g\":\"${ssid_2g}\",\"pswd_2g\":\"${pswd_2g}\",\"mgmt_2g\":\"${mgmt_2g}\",\"ssid_5g\":\"${ssid_5g}\",\"pswd_5g\":\"${pswd_5g}\",\"mgmt_5g\":\"${mgmt_5g}\",\"bh_ssid\":\"${bh_ssid}\",\"bh_pswd\":\"${bh_pswd}\",\"bh_mgmt\":\"psk2\",\"bh_macnum_5g\":\"${bh_macnum_5g}\",\"bh_maclist_5g\":\"${bh_maclist_5g}\",\"bh_macnum_2g\":\"0\",\"bh_maclist_2g\":\"\",\"ssid_game\":\"${ssid_game}\",\"pswd_game\":\"${pswd_game}\",\"mgmt_game\":\"${mgmt_game}\"}}"

		mimesh_init "$buff"
	fi

	check_cap_init_status_v2 $name $1 $3 $5 $is_cable
}

do_re_dhcp() {
	local bridge="br-lan"
	local ifname=$(uci -q get misc.wireless.apclient_${BHDEV})
	local model=$(uci -q get misc.hardware.model)
	[ -z "$model" ] && model=$(cat /proc/xiaoqiang/model)

	#tcpdump -i wl11 port 47474 -w /tmp/aaa &
	iw dev $ifname set 4addr on >/dev/null 2>&1
	iwpriv ${ifname} wds 1
	brctl addif br-lan ${ifname}

	#request dhcp-IP with bridge MAC as clientid, to avoid get different ip on br-lan later.
	ifconfig br-lan 0.0.0.0
	mac=$(ifconfig ${bridge} | grep -o "HWaddr\s\S*" | awk '{print $2}')
	client_id="01${mac//:/}"
	#udhcpc on br-lan, for re init time optimization
	#get dhcp-IP only to varify network and DHCP can work correctly
	#later udhcpc will running as daemon on br-lan by netifd-controller.
	udhcpc -q -p /var/run/udhcpc-${bridge}.pid -s /usr/share/udhcpc/mesh_dhcp.script -f -t 0 -i $bridge -x hostname:MiWiFi-${model} -x "0x3d:$client_id"

	exit $?
}

re_start_wps() {
	local ifname=$(uci -q get misc.wireless.apclient_${BHDEV})
	local ifname_5G=$(uci -q get misc.wireless.ifname_${bh_tag})
	local device=$(uci -q get misc.wireless.${ifname}_device)
	local channel="$2"

	eth_down

	wpa_supplicant_if_remove $ifname
	wlanconfig $ifname destroy -cfg80211

	[ "$bh_tag" = "$BHTAG" ] && {
		case "$channel" in
			52|56|60|64|100|104|108|112|116|120|124|128|132|136|140|149|153|157|161|165) channel=36
				;;
			*) ;;
		esac
	} || {
		case "$channel" in
			36|40|44|48|52|56|60|64) channel=0
				;;
			*) ;;
		esac
	}

	cfg80211tool $ifname_5G channel $channel
	sleep 2

	wlanconfig $ifname create wlandev $device wlanmode sta -cfg80211
	iw dev $device interface add $ifname type __ap
	cfg80211tool $ifname channel $channel
	sleep 2

	rm -f /var/run/wpa_supplicant-${ifname}.conf
	echo -e "ctrl_interface=/var/run/wpa_supplicant\nctrl_interface_group=0\nupdate_config=1" | tee /var/run/wpa_supplicant-${ifname}.conf

	wpa_supplicant_if_add $ifname "br-lan"
	sleep 1

	wpa_cli -p /var/run/wpa_supplicant-$ifname -i $ifname wps_pbc "$1"

	for i in $(seq 1 60)
	do
		status=$(wpa_cli -p /var/run/wpa_supplicant-$ifname -i ${ifname} status | grep ^wpa_state= | cut -f2- -d=)
		if [ "$status" == "COMPLETED" ]; then
			#do_re_init $ifname $1
			exit 0
		fi
		sleep 2
	done

	eth_up

	wpa_supplicant_if_remove $ifname
	rm -f /var/run/wpa_supplicant-${ifname}.conf
	wlanconfig $ifname destroy -cfg80211
	wifi

	exit 1
}

cap_create_vap() {
	local ifname="$2"
	local device="$1"
	local channel="$3"
	local wifi_mode="$4"
	local ifname_5G=$(uci -q get misc.wireless.ifname_${bh_tag})
	local macaddr=$(cat /sys/class/net/br-lan/address)
	local uuid=$(echo "$macaddr" | sed 's/://g')
	local ssid=$(uci -q get wireless.@wifi-iface[0].ssid)
	local key=$(openssl rand -base64 8 | md5sum | cut -c1-32)
	local model=$(uci -q get misc.hardware.model)
	[ -z "$model" ] && model=$(cat /proc/xiaoqiang/model)

	cp -f /usr/share/mesh/hostapd-template.conf /var/run/hostapd-${ifname}.conf

	case "$channel" in
		52|56|60|64|100|104|108|112|116|120|124|128|132|136|140|149|153|157|161|165)
			channel=36
			if [ "$wifi_mode" = "11AHE160" -o "$wifi_mode" = "11ACVHT160" ]; then
				[ "$wifi_mode" = "11AHE160" ] && wifi_mode="11AHE80" || wifi_mode="11ACVHT80"
				cfg80211tool $ifname_5G mode $wifi_mode
				sleep 1
			fi
			;;
		*) ;;
	esac

	echo -e "interface=$ifname" >> /var/run/hostapd-${ifname}.conf
	echo -e "model_name=$model" >> /var/run/hostapd-${ifname}.conf
	[ -z "$channel" ] || echo -e "channel=$channel" >> /var/run/hostapd-${ifname}.conf
	echo -e "wpa_passphrase=$key" >> /var/run/hostapd-${ifname}.conf
	echo -e "ssid=$ssid" >> /var/run/hostapd-${ifname}.conf
	echo -e "uuid=87654321-9abc-def0-1234-$uuid" >> /var/run/hostapd-${ifname}.conf
	echo -e "ctrl_interface=/var/run/hostapd-$device" >> /var/run/hostapd-${ifname}.conf

	wlanconfig $ifname create wlandev $device wlanmode ap -cfg80211
	iw dev $device interface add $ifname type __ap
	[ -z "$channel" ] || cfg80211tool $ifname channel $channel
	[ -z "$wifi_mode" ] || cfg80211tool $ifname mode $wifi_mode

	for i in $(seq 1 10)
	do
		sleep 2
		local acs_state_son=$(iwpriv $ifname get_acs_state | cut -f2- -d ':')
		local acs_state_main=$(iwpriv $ifname_5G get_acs_state | cut -f2- -d ':')
		if [ $acs_state_son -eq 0 -a $acs_state_main -eq 0 ]; then
			break
		fi
	done

	hostapd /var/run/hostapd-${ifname}.conf &
}

cap_start_wps() {
	local ifname=$(uci -q get misc.wireless.mesh_ifname_5G)
	#use wifi2
	local device=$(uci -q get misc.wireless.if_${bh_tag})
	[ "$bh_tag" = "$BHTAG_SEC" ] && {
		device=$(uci -q get misc.wireless.if_${BHDEV})
	}
	local status_file=$(echo $1 | sed s/[:]//g)
	#use wifi2
	local ifname_5G=$(uci -q get misc.wireless.ifname_${bh_tag})
	local wifi_mode=$(cfg80211tool "$ifname_5G" get_mode | awk -F':' '{print $2}')
	local channel=$(iwinfo "$ifname_5G" f | grep \* | awk '{print $5}' | sed 's/)//g')
	local netmode=$(uci -q get xiaoqiang.common.NETMODE)
	#local re_bssid=$1
	#local obssid_jsonbuf=$(cat /var/run/scanrelist | grep -i "$re_bssid")
	#local obssid=$(json_get_value "$obssid_jsonbuf" "obssid")
	#local re_mesh_ver=$(json_get_value "$obssid_jsonbuf" "mesh_ver")
	#[ -z "$re_mesh_ver" ] && re_mesh_ver=2
	#local obsta_mac
	#[ -n "$obssid" -a "00:00:00:00:00:00" -ne "$obssid" ] && obsta_mac=$(calcbssid -i 1 -m $obssid)

	echo "init" > /tmp/${status_file}-status
	#wifi2 was 5G low freq
	radartool -n -i $device ignorecac 1
	radartool -n -i $device disable
	sleep 2
	cap_create_vap "$device" "$ifname" "$channel" "$wifi_mode"
	sleep 2

	iwpriv $ifname miwifi_mesh 2
	iwpriv $ifname miwifi_mesh_mac $1

	cfg80211tool $ifname maccmd_sec 3
	#cfg80211tool $ifname addmac_sec $2
	#[ -n "$obsta_mac" -a "00:00:00:00:00:00" -ne "$obsta_mac" ] && cfg80211tool $ifname addmac_sec $obsta_mac
	cfg80211tool $ifname maccmd_sec 0

	hostapd_cli -i $ifname -p /var/run/hostapd-${device} -P /var/run/hostapd_cli-${ifname}.pid update_beacon
	hostapd_cli -i $ifname -p /var/run/hostapd-${device} -P /var/run/hostapd_cli-${ifname}.pid wps_pbc

	for i in $(seq 1 60)
	do
		wps_status=$(hostapd_cli -i ${ifname} -p /var/run/hostapd-${device} -P /var/run/hostapd_cli-${ifname}.pid wps_get_status | grep 'Last\ WPS\ result:' | cut -f4- -d ' ')
		pbc_status=$(hostapd_cli -i ${ifname} -p /var/run/hostapd-${device} -P /var/run/hostapd_cli-${ifname}.pid wps_get_status | grep 'PBC\ Status:' | cut -f3- -d ' ')
		if [ "$wps_status" == "Success" ]; then
			if [ "$pbc_status" == "Disabled" ]; then
				echo "connected" > /tmp/${status_file}-status
				cap_disable_wps_trigger  $device $ifname
				#wifi2 was 5G low freq
				radartool -n -i $device enable
				radartool -n -i $device ignorecac 0

				exit 0
			fi
		fi
		sleep 2
	done

	#cap_close_wps
	cap_delete_vap
	echo "failed" > /tmp/${status_file}-status

	#wifi2 was 5G low freq
	radartool -n -i $device enable
	radartool -n -i $device ignorecac 0

	case "$channel" in
		52|56|60|64|100|104|108|112|116|120|124|128|132|136|140|149|153|157|161|165)
			cfg80211tool $ifname_5G channel $channel
			if [ "$wifi_mode" = "11AHE160" -o "$wifi_mode" = "11ACVHT160" ]; then
				cfg80211tool $ifname_5G mode $wifi_mode
			fi
			;;
		*) ;;
	esac

	exit 1
}

case "$1" in
	re_start)
	re_start_wps "$2" "$3"
	;;
	cap_start)
	cap_start_wps "$2" "$3"
	;;
	cap_close)
	cap_close_wps
	;;
	init_cap)
	init_cap_mode
	;;
	cap_init)
	run_with_lock do_cap_init "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9"
	;;
	cap_init_bsd)
	do_cap_init_bsd "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9"
	;;
	re_init)
	run_with_lock do_re_init "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "$10" "$11"
	;;
	re_init_bsd)
	do_re_init_bsd "$2" "$3" "$4" "$5" "$6" "$7" "$8"
	;;
	re_dhcp)
	do_re_dhcp
	;;
	cap_create)
	cap_create_vap "$2" "$3"
	;;
	cap_clean)
	cap_clean_vap "$2" "$3"
	;;
	re_clean)
	re_clean_vap
	;;
	re_init_json)
	do_re_init_json "$2"
	;;
	*)
	usage
	;;
esac
