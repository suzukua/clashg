#!/bin/bash
source /koolshare/scripts/base.sh
source /koolshare/clashg/base.sh

clashg_enable=$(get clashg_enable) #on:启用, off:停用
clashg_subscribe_args=$(get clashg_subscribe_args)
clashg_geoip_url=$(get clashg_geoip_url)

# 用于返回JSON格式数据: {result: id, status: ok, data: {key:value, ...}}
response_json() {
  # 其中 data 内容格式示例: "{\"key\":\"value\"}"
  # 参数说明:
  #   $1: 请求ID
  #   $2: 想要传递给页面的JSON数据:格式为:key=value\nkey=value\n...
  #   $3: 返回状态码, ok为成功, error等其他为失败
  http_response "$1\",\"data\": "$2", \"status\": \"$3"  >/dev/null 2>&1
}

get_config_file(){
  if [ ! -f $clash_edit_file ]; then
      cp $clash_ro_file $clash_edit_file
  fi
  cat $clash_edit_file | base64_encode
}

save_config_file(){
  local config_file_base64=$1
  echo -n ${config_file_base64} | base64_decode > $clash_edit_file
}

reset_config_file(){
  cp $clash_ro_file $clash_edit_file
}

get_run_config_file(){
  local file_content="暂无运行配置，请先订阅"
  if [ -f $clash_file ]; then
      file_content=$(cat $clash_file)
  fi
  echo "$file_content" | base64_encode
}

get_status(){
  #返回clash=key:value-key:value;gfw=key:value-key:value
  clash_status="Clash="
  clashpid="$(pidof clash)"
  if [ -z "$clashpid" ]; then
    clash_status="${clash_status}启动状态:不正常"
  else
    clash_status="${clash_status}启动状态:正常(pid>${clashpid})"
  fi
  if [ ! -f "$clash_file" ]; then
    clash_status="${clash_status}-clash.yaml:不存在"
  fi

  iptables_status="IPTABLES="
  iptables_count=$(iptables -t mangle -vnL PREROUTING --line-number |grep -c "$mangle_name")
#  iptables_count=$(iptables -t nat -vnL PREROUTING --line-number |grep -c "$proxy_port")
  if [ "$iptables_count" -ne "1" ]; then
    iptables_status="${iptables_status}状态:不正常(${mangle_name}链未添加到mangle表)"
  else
    iptables_status="${iptables_status}状态:正常(${mangle_name}链已到mangle表添加)"
  fi
  if [ -f "$clash_file" ]; then
    it4_mixp_count=$(iptables -vnL INPUT --line-number |grep -c "$shadowsocksport")
    it6_mixp_count=$(ip6tables -vnL INPUT --line-number |grep -c "$shadowsocksport")
    iptables_status="${iptables_status}-Shadowsocks:(IPV4 ${it4_mixp_count}条,IPV6 ${it6_mixp_count}条)"
  fi

  ipset_status="IPSET分流="
  ipset_txt=$(ipset list|grep "$gfw_cidr_ipset")
  if [ -z "$ipset_txt" ]; then
    ipset_status="${ipset_status}状态:不正常(${gfw_cidr_ipset}未创建)"
  else
    ipset_file_count=$(head -n 1 $ipcidr_file  | awk -F: '/^#\ Rows:/{print $2}' | xargs echo -n)
    ipset_import_count=$(ipset list "$gfw_cidr_ipset" | grep -c "/")
    ipset_status="${ipset_status}状态:正常(ipset已导入${ipset_import_count}行, ipset文件${ipset_file_count}行)"
  fi

  gfw_status="GFW域名分流="
  if [ -f /jffs/configs/dnsmasq.d/clashg_gfw.conf  ]; then
    gfw_rows=$(head -n 1 /jffs/configs/dnsmasq.d/clashg_gfw.conf | awk -F: '/^#\ Rows:/{print $2}' | xargs echo -n)
    gfw_status="${gfw_status}文件挂载:正常(${gfw_rows}条)"
  else
    gfw_status="${gfw_status}文件挂载:不正常"
  fi

  clash_tcp_count=$(netstat -anp |grep clash |grep  -v ":::\|LISTEN" |grep tcp -c)
  clash_udp_count=$(netstat -anp |grep clash |grep  -v ":::\|LISTEN" |grep udp -c)
  netstat_status="NETSTAT连接数=TCP:${clash_tcp_count}条-UDP:${clash_udp_count}条"

  echo "$clash_status;$gfw_status;$ipset_status;$iptables_status;$netstat_status"
}

merge_run_yaml(){
  LOGGER "合并配置到${clash_file}" >> $LOG_FILE
  #自定义配置文件不存在则从原厂配置copy一份
  if [ ! -f $clash_edit_file ]; then
    cp $clash_ro_file $clash_edit_file
  fi
  $clashg_dir/yq merge $clash_edit_file $clash_sub_file > $clash_file
  LOGGER "合并配置完成" >> $LOG_FILE
}

do_action() {
  ACTION="$2"
  case $ACTION in
    start)
      if [ "$clashg_enable" == "on" ]; then
        echo > $LOG_FILE #重置日志
        merge_run_yaml
        sh $clashg_dir/clashconfig.sh start
        ret_data="{$(dbus list clashg_ | awk '{sub("=", "\":\""); printf("\"%s\",", $0)}'|sed 's/,$//')}"
        [ "$1" -ne "-1" ] && response_json "$1" "$ret_data" "ok"
      fi
    ;;
    stop)
      if [ "$clashg_enable" != "on" ]; then
        sh $clashg_dir/clashconfig.sh stop
        ret_data="{$(dbus list clashg_ | awk '{sub("=", "\":\""); printf("\"%s\",", $0)}'|sed 's/,$//')}"
        response_json "$1" "$ret_data" "ok"
      fi
    ;;
    start_nat)
      if [ "$clashg_enable" == "on" ]; then
        echo > $LOG_FILE #重置日志
        sh $clashg_dir/clashconfig.sh start_nat
        ret_data="{$(dbus list clashg_ | awk '{sub("=", "\":\""); printf("\"%s\",", $0)}'|sed 's/,$//')}"
        [ "$1" -ne "-1" ] && response_json "$1" "$ret_data" "ok"
      fi
    ;;
    get_config_file)
      ret_data=$(get_config_file)
      response_json "$1" "\"$ret_data\"" "ok"
    ;;
    save_config_file)
      save_config_file $3
      response_json "$1" "\"\"" "ok"
    ;;
    reset_config_file)
      reset_config_file
      response_json "$1" "\"\"" "ok"
    ;;
    update_dns_ipset_rule)
      sh $clashg_dir/clashconfig.sh update_dns_ipset_rule
      ret_data="{$(dbus list clashg_ | awk '{sub("=", "\":\""); printf("\"%s\",", $0)}'|sed 's/,$//')}"
      response_json "$1" "$ret_data" "ok"
    ;;
    update_geoip)
      sh $clashg_dir/clashconfig.sh update_geoip $clashg_geoip_url
      ret_data="{$(dbus list clashg_ | awk '{sub("=", "\":\""); printf("\"%s\",", $0)}'|sed 's/,$//')}"
      [ "$1" -ne "-1" ] && response_json "$1" "$ret_data" "ok" #定时任务更新不执行
    ;;
    subscribe)
      [ -n "$clashg_subscribe_args" ] && sh $clashg_dir/clashg_subconverter.sh $clashg_subscribe_args
      ret_data="{$(dbus list clashg_ | awk '{sub("=", "\":\""); printf("\"%s\",", $0)}'|sed 's/,$//')}"
      response_json "$1" "$ret_data" "ok"
    ;;
    update_cron|set_mixed_port_status)
      ret_data="{$(dbus list clashg_ | awk '{sub("=", "\":\""); printf("\"%s\",", $0)}'|sed 's/,$//')}"
      response_json "$1" "$ret_data" "ok"
    ;;
    update_rule_sub_restart)
      if [ "$clashg_enable" == "on" ]; then
        echo > $LOG_FILE #重置日志
        LOGGER "定时更新开始"
        #更新翻墙规则
        sh $clashg_dir/clashconfig.sh update_dns_ipset_rule
        merge_run_yaml
        #更新订阅
        [ -n "$clashg_subscribe_args" ] && sh $clashg_dir/clashg_subconverter.sh $clashg_subscribe_args
        sh $clashg_dir/clashconfig.sh start
        LOGGER "定时更新结束, 重启完毕"
      fi
    ;;
    get_status)
      ret_data=$(get_status)
      response_json "$1" "\"$ret_data\"" "ok"
    ;;
    get_run_config_file)
      ret_data=$(get_run_config_file)
      response_json "$1" "\"$ret_data\"" "ok"
    ;;
  esac
}

echo >> $LOG_FILE
if [ "$1" == "start" -o "$1" == "start_nat" ]; then
  do_action -1 $@ 2>&1 | tee -a $LOG_FILE
else
  do_action $@ 2>&1 | tee -a $LOG_FILE
fi

echo "XU6J03M6" >> $LOG_FILE
