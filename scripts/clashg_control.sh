#!/bin/bash
source /koolshare/scripts/base.sh
source /koolshare/clashg/base.sh

clashg_enable=$(get clashg_enable) #on:启用, off:停用

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
  #[{key:"name1",value:"value"},{key:"name1",value:"value"}]
  clash_status="{\"key\":\"Clash\",\"value\":\""
  clashpid="$(pidof clash)"
  version=$($clashg_dir/clash -v | grep -o 'Mihomo Meta v[0-9]\+\.[0-9]\+\.[0-9]\+')
  if [ -z "$clashpid" ]; then
    clash_status="${clash_status}启动状态:不正常($version)"
  else
    clash_status="${clash_status}启动状态:正常,pid>${clashpid}($version)"
  fi
  if [ ! -f "$clash_file" ]; then
    clash_status="${clash_status}-clash.yaml:不存在"
  fi
  clash_status="${clash_status}\"}"

  iptables_status="{\"key\":\"IPTABLES\",\"value\":\""
  iptables_count=$(iptables -t mangle -vnL PREROUTING --line-number |grep -c "$mangle_name")
  if [ "$iptables_count" -ne "1" ]; then
    iptables_status="${iptables_status}状态:不正常(${mangle_name}链未添加到mangle表)"
  else
    iptables_status="${iptables_status}状态:正常(${mangle_name}链已到mangle表添加)"
  fi
  if [ -f "$clash_file" ]; then
    it4_mixp_count=$(iptables -vnL INPUT --line-number |grep -c "$shadowsocksport")
    it6_mixp_count=$(ip6tables -vnL INPUT --line-number |grep -c "$shadowsocksport")
    iptables_status="${iptables_status}</br>Shadowsocks:(IPV4 ${it4_mixp_count}条,IPV6 ${it6_mixp_count}条)"
  fi
  iptables_status="${iptables_status}\"}"

  ipset_status="{\"key\":\"IPSET分流\",\"value\":\""
  ipset_txt=$(ipset list|grep "$gfw_cidr_ipset")
  if [ -z "$ipset_txt" ]; then
    ipset_status="${ipset_status}状态:不正常(${gfw_cidr_ipset}未创建)"
  else
    ipset_file_count=$(head -n 1 $ipcidr_file  | awk -F: '/^#\ Rows:/{print $2}' | xargs echo -n)
    rule_update=$(head -n 2 $ipcidr_file | tail -1  | awk -F 'on:' '/^#\ Updated\ on:/{print $2}' | xargs echo -n)
    ipset_import_count=$(ipset list "$gfw_cidr_ipset" | grep -c "/")
    ipset_status="${ipset_status}状态:正常,ipset已导入${ipset_import_count}行,ipset文件${ipset_file_count}行($rule_update)"
  fi
  ipset_status="${ipset_status}\"}"

  gfw_status="{\"key\":\"GFW域名分流\",\"value\":\""
  if [ -f /jffs/configs/dnsmasq.d/clashg_gfw.conf  ]; then
    gfw_rows=$(head -n 1 /jffs/configs/dnsmasq.d/clashg_gfw.conf | awk -F: '/^#\ Rows:/{print $2}' | xargs echo -n)
    gfw_rule_update=$(head -n 2 /jffs/configs/dnsmasq.d/clashg_gfw.conf | tail -1 | awk -F 'on:' '/^#\ Updated\ on:/{print $2}' | xargs echo -n)
    gfw_status="${gfw_status}文件挂载:正常,${gfw_rows}条($gfw_rule_update)"
  else
    gfw_status="${gfw_status}文件挂载:不正常"
  fi
  gfw_status="${gfw_status}\"}"

  clash_tcp_count=$(netstat -anp |grep clash |grep  -v ":::\|LISTEN" |grep tcp -c)
  clash_udp_count=$(netstat -anp |grep clash |grep  -v ":::\|LISTEN" |grep udp -c)
  netstat_status="{\"key\":\"NETSTAT连接数\",\"value\":\"TCP:${clash_tcp_count}条,UDP:${clash_udp_count}条\"}"

  echo "[$clash_status,$gfw_status,$ipset_status,$iptables_status,$netstat_status]"
}

#查询clash 面板信息
get_board_info(){
  if [ -f $clash_file ]; then
    external=$(grep "external-controller-tls:" $clash_file | awk -F': ' '{print $2}')
    if [ -z "$external" ]; then
        external=$(grep "external-controller:" $clash_file | awk -F': ' '{print $2}')
    fi
    if [ -n "$external" ]; then
        ip=$(echo "$external" | cut -d : -f 1)
        port=$(echo "$external" | cut -d : -f 2)
        secret="$(grep "secret:" $clash_file | awk -F': ' '{print $2}')"
        echo "{\"ip\":\"$ip\",\"port\":\"$port\",\"secret\":\"$secret\"}"
        return 0
    fi
  fi
  echo "{}"

}

merge_run_yaml(){
  LOGGER "生成配置到${clash_file}，请耐心等待" >> $LOG_FILE
  #自定义配置文件不存在则从原厂配置copy一份
  if [ ! -f $clash_edit_file ]; then
    cp $clash_ro_file $clash_edit_file
  fi
  cp $clash_edit_file $clash_file
  LOGGER "生成配置完成" >> $LOG_FILE
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
      save_config_file "$(get clashg_yaml_edit_content)"
      #临时保存到dbus，保存完毕删除
      dbus remove clashg_yaml_edit_content
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
    update_cron|set_mixed_port_status|save_clashg_gfw_file)
      ret_data="{$(dbus list clashg_ | awk '{sub("=", "\":\""); printf("\"%s\",", $0)}'|sed 's/,$//')}"
      response_json "$1" "$ret_data" "ok"
    ;;
    update_rule)
      if [ "$clashg_enable" == "on" ]; then
        echo > $LOG_FILE #重置日志
        LOGGER "定时更新规则开始"
        #更新翻墙规则
        sh $clashg_dir/clashconfig.sh update_dns_ipset_rule
        sh $clashg_dir/clashconfig.sh out_restart_dnsmasq
        LOGGER "定时更新规则结束"
      fi
    ;;
    get_status)
      status_info=$(get_status)
      board_info=$(get_board_info)
      response_json "$1" "{\"status_info\":$status_info, \"board_info\":$board_info}" "ok"
    ;;
    get_run_config_file)
      ret_data=$(get_run_config_file)
      response_json "$1" "\"$ret_data\"" "ok"
    ;;
  esac
}

echo >> $LOG_FILE
LOGGER $1 "=========ACTION=========" $2 "====" $3 >> $LOG_FILE
if [ "$1" == "start" -o "$1" == "start_nat" ]; then
  do_action -1 $@ 2>&1 | tee -a $LOG_FILE
else
  do_action $@ 2>&1 | tee -a $LOG_FILE
fi
echo "XU6J03M6" >> $LOG_FILE
