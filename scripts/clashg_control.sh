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

get_status(){
  #返回clash=key:value-key:value;gfw=key:value-key:value
  clash_status="clash="
  clashpid="$(pidof clash)"
  if [ -z "$clashpid" ]; then
    clash_status="${clash_status}启动状态:不正常"
  else
    clash_status="${clash_status}启动状态:正常(pid>${clashpid})"
  fi

  iptables_status="iptables="
  iptables_count=$(iptables -t nat -vnL PREROUTING --line-number |grep -E -c "$dnsmasq_gfw_ipset|$gfw_cidr_ipset")
  if [ "$iptables_count" -ne "2" ]; then
    iptables_status="${iptables_status}状态:不正常(${iptables_count}条)"
  else
    iptables_status="${iptables_status}状态:正常(${iptables_count}条)"
  fi

  ipset_status="ipset分流规则="
  ipset_txt=$(ipset list|grep "$gfw_cidr_ipset")
  if [ -z "$ipset_txt" ]; then
    ipset_status="${ipset_status}状态:不正常(${gfw_cidr_ipset}未创建)"
  else
    ipset_file_count=$(head -n 1 $ipcidr_file  | awk -F: '/^#\ Rows:/{print $2}' | xargs echo -n)
    ipset_import_count=$(ipset list "$gfw_cidr_ipset" | grep -c "/")
    ipset_status="${ipset_status}状态:正常(ipset已导入${ipset_import_count}行, ipset文件${ipset_file_count}行)"
  fi

  gfw_status="gfw分流规则="
  if [ -f /jffs/configs/dnsmasq.d/clashg_gfw.conf  ]; then
    gfw_rows=$(head -n 1 /jffs/configs/dnsmasq.d/clashg_gfw.conf | awk -F: '/^#\ Rows:/{print $2}' | xargs echo -n)
    gfw_status="${gfw_status}文件挂载:正常(${gfw_rows}条)"
  else
    gfw_status="${gfw_status}文件挂载:不正常"
  fi
  echo "$clash_status;$gfw_status;$ipset_status;$iptables_status"
}
do_action() {
  ACTION="$2"
  case $ACTION in
    start)
      if [ "$clashg_enable" == "on" ]; then
        echo > $LOG_FILE #重置日志
        sh $clashg_dir/clashconfig.sh start
        ret_data="{$(dbus list clashg_ | awk '{sub("=", "\":\""); printf("\"%s\",", $0)}'|sed 's/,$//')}"
        response_json "$1" "$ret_data" "ok"
      fi
    ;;
    stop)
      if [ "$clashg_enable" != "on" ]; then
        sh $clashg_dir/clashconfig.sh stop
        ret_data="{$(dbus list clashg_ | awk '{sub("=", "\":\""); printf("\"%s\",", $0)}'|sed 's/,$//')}"
        response_json "$1" "$ret_data" "ok"
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
  esac
}

echo >> $LOG_FILE
do_action $@ 2>&1 | tee -a $LOG_FILE
echo "XU6J03M6" >> $LOG_FILE