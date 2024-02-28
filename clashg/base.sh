#!/bin/bash
clashg_dir=/koolshare/clashg
LOG_FILE=/tmp/upload/clashglog.txt

clash_ro_file="${clashg_dir}/clash_ro.yaml" #原厂配置
clash_edit_file="${clashg_dir}/custom_clash_edit.yaml" #修改的配置
clash_file="${clashg_dir}/clash.yaml" #程序运行时的配置

github_proxy="https://mirror.ghproxy.com/"
CURL_OPTS="-s -k"


#DNS后置采用dnsmasq+gfw分流模式
#分流出来的流量根据ipset重定向到clash redir-port
remote_gfw_conf_full='https://cdn.jsdelivr.net/gh/zhudan/gfwlist2dnsmasq@hidden/gfw.conf'
remote_gfw_conf_lite='https://cdn.jsdelivr.net/gh/zhudan/gfwlist2dnsmasq@hidden/gfw_lite.conf'
remote_proxy_cidr='https://cdn.jsdelivr.net/gh/zhudan/gfwlist2dnsmasq@hidden/ip-cidr.ipset'

dnsmasq_gfw_ipset="dnsmasq_gfw"
gfw_cidr_ipset="gfw_cidr"

#mangle 表名字
mangle_name=clashg

gfw_file=/tmp/clashg_gfw.conf
ipcidr_file=/tmp/clashg_cidr_tmp.txt

shadowsocksport=""
tproxy_port=""
inbound_tfo=""
if [ -f $clash_file ]; then
  shadowsocksport=$(grep shadowsocks $clash_file  | awk -F'[:,]' '{for(i=1;i<=NF;i++){if($i~/port/)print $(i+1)}}'| tr -d ' ')
  tproxy_port=$(cat $clash_file | awk -F: '/^tproxy-port/{print $2}' | xargs echo -n)
  inbound_tfo=$(cat $clash_file | awk -F: '/^inbound-tfo/{print $2}' | xargs echo -n)
fi

LOGGER() {
    echo -e "【$(date +'%Y年%m月%d日 %H:%M:%S')】: $@"
}

SYSLOG() {
    logger -t "【$(date +'%Y年%m月%d日 %H:%M:%S')】:clashg" "$@"
}

get(){
	a="$(echo $(dbus get $1))"
	echo $a
}

#如果是github资源则增加代理前缀
get_direct_url(){
  origin_url=$1
  is_github=$(expr "$origin_url" : https\:\/\/raw\.githubusercontent\.com.* || expr "$origin_url" : https\:\/\/github\.com.*;)
  if [ "$is_github" -gt "0" ]; then
    origin_url="${github_proxy}${origin_url}"
  fi
  echo "$origin_url"
}
