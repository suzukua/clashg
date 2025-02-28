#!/bin/sh

source /koolshare/scripts/base.sh
source /koolshare/clashg/base.sh

clashg_update_rule_cron_base64=$(get clashg_update_rule_cron)
clashg_mixed_port_status=$(get clashg_mixed_port_status)
clashg_gfw_file=$(get clashg_gfw_file)

LOCK_FILE=/var/lock/clashg.lock

set_lock() {
  exec 1000>"$LOCK_FILE"
  flock -x 1000
}

unset_lock() {
  flock -u 1000
  rm -rf "$LOCK_FILE"
}

auto_start() {
  LOGGER "创建开自启动脚本" >> $LOG_FILE
  [ ! -L "/koolshare/init.d/S99clashg.sh" ] && ln -sf /koolshare/scripts/clashg_control.sh /koolshare/init.d/S99clashg.sh
  [ ! -L "/koolshare/init.d/N99clashg.sh" ] && ln -sf /koolshare/scripts/clashg_control.sh /koolshare/init.d/N99clashg.sh
}

add_nat(){
  if [ "${clashg_mixed_port_status}" == "on" -a -n "$shadowsocksport" ]; then
    LOGGER "开启Shadowsocks: ${shadowsocksport}公网访问" >> $LOG_FILE
    iptables -I INPUT -p tcp --dport $shadowsocksport -j ACCEPT
    iptables -I INPUT -p udp --dport $shadowsocksport -j ACCEPT
    ip6tables -I INPUT -p tcp --dport $shadowsocksport -j ACCEPT
    ip6tables -I INPUT -p udp --dport $shadowsocksport -j ACCEPT
  fi
  # tproxy模式
  if [ -z "$(lsmod |grep "xt_TPROXY")" ]; then
    modprobe -a "xt_TPROXY"  >/dev/null 2>&1
  fi
  # IPV4
  ip rule add fwmark 10 table 100
  ip route add local 0.0.0.0/0 dev lo table 100
  iptables -t mangle -N "$mangle_name"
  iptables -t mangle -F "$mangle_name"
  iptables -t mangle -A "$mangle_name" -d 0.0.0.0/8 -j RETURN
  iptables -t mangle -A "$mangle_name" -d 127.0.0.0/8 -j RETURN
  iptables -t mangle -A "$mangle_name" -d 10.0.0.0/8 -j RETURN
  iptables -t mangle -A "$mangle_name" -d 172.16.0.0/12 -j RETURN
  iptables -t mangle -A "$mangle_name" -d 192.168.0.0/16 -j RETURN
  iptables -t mangle -A "$mangle_name" -d 169.254.0.0/16 -j RETURN
  iptables -t mangle -A "$mangle_name" -d 224.0.0.0/4 -j RETURN
  iptables -t mangle -A "$mangle_name" -d 240.0.0.0/4 -j RETURN
  iptables -t mangle -A "$mangle_name" -d 255.255.255.255/32 -j RETURN
  iptables -t mangle -A "$mangle_name" -p tcp -m set --match-set $dnsmasq_gfw_ipset dst -j TPROXY --on-port $tproxy_port --tproxy-mark 10
  iptables -t mangle -A "$mangle_name" -p udp -m set --match-set $dnsmasq_gfw_ipset dst -j TPROXY --on-port $tproxy_port --tproxy-mark 10
  iptables -t mangle -A "$mangle_name" -p tcp -m set --match-set $gfw_cidr_ipset dst -j TPROXY --on-port $tproxy_port --tproxy-mark 10
  iptables -t mangle -A "$mangle_name" -p udp -m set --match-set $gfw_cidr_ipset dst -j TPROXY --on-port $tproxy_port --tproxy-mark 10
  iptables -t mangle -A PREROUTING -j "$mangle_name"

  # IPV6
  # 设置策略路由 v6
  ip -6 rule add fwmark 10 table 100
  ip -6 route add local ::/0 dev lo table 100
  ip6tables -t mangle -N "$mangle_name6"
  ip6tables -t mangle -F "$mangle_name6"
  ip6tables -t mangle -A "$mangle_name6" -d ::1/128 -j RETURN
  ip6tables -t mangle -A "$mangle_name6" -d fe80::/10 -j RETURN
  ip6tables -t mangle -A "$mangle_name6" -d fd00::/8 -p tcp -j RETURN
  ip6tables -t mangle -A "$mangle_name6" -p tcp -m set --match-set $dnsmasq_gfw_ipset6 dst -j TPROXY --on-port $tproxy_port --tproxy-mark 10
  ip6tables -t mangle -A "$mangle_name6" -p udp -m set --match-set $dnsmasq_gfw_ipset6 dst -j TPROXY --on-port $tproxy_port --tproxy-mark 10
  ip6tables -t mangle -A "$mangle_name6" -p tcp -m set --match-set $gfw_cidr_ipset6 dst -j TPROXY --on-port $tproxy_port --tproxy-mark 10
  ip6tables -t mangle -A "$mangle_name6" -p udp -m set --match-set $gfw_cidr_ipset6 dst -j TPROXY --on-port $tproxy_port --tproxy-mark 10
  ip6tables -t mangle -A PREROUTING -j "$mangle_name6"

  LOGGER "iptables IPV4+IPV6 建立完成" >> $LOG_FILE
}
rm_nat(){
  LOGGER 删除iptables开始 >> $LOG_FILE
  #tproxy模式
  #IPV4
  ip rule del fwmark 10 table 100 >/dev/null 2>&1
  ip route del local 0.0.0.0/0 dev lo table 100 >/dev/null 2>&1
  #删除
  ipset_indexs=$(iptables -t mangle -L PREROUTING --line-number | sed 1,2d | sed -n "/${mangle_name}/=" | sort -r)
  for ipset_index in $ipset_indexs; do
    iptables -t mangle -D PREROUTING $ipset_index >/dev/null 2>&1
  done
  iptables -t mangle -D PREROUTING -j "$mangle_name" >/dev/null 2>&1
  #清空
  iptables -t mangle -F "$mangle_name" >/dev/null 2>&1
  #删除
  iptables -t mangle -X "$mangle_name" >/dev/null 2>&1

  #IPV6
  ip -6 rule del fwmark 10 table 100 >/dev/null 2>&1
  ip -6 route del local ::/0 dev lo table 100 >/dev/null 2>&1
  #删除
  ipset_indexs=$(ip6tables -t mangle -L PREROUTING --line-number | sed 1,2d | sed -n "/${mangle_name6}/=" | sort -r)
  for ipset_index in $ipset_indexs; do
    ip6tables -t mangle -D PREROUTING $ipset_index >/dev/null 2>&1
  done
  ip6tables -t mangle -D PREROUTING -j "$mangle_name6" >/dev/null 2>&1
  #清空
  ip6tables -t mangle -F "$mangle_name6" >/dev/null 2>&1
  #删除
  ip6tables -t mangle -X "$mangle_name6" >/dev/null 2>&1

  # 清理shadowsocksport端口
  if [ -n "$shadowsocksport" ]; then
    ipset_indexs=$(iptables -vnL INPUT --line-number | sed 1,2d | sed -n "/${shadowsocksport}/=" | sort -r)
    for ipset_index in $ipset_indexs; do
      iptables -D INPUT $ipset_index >/dev/null 2>&1
    done
    ipset_indexs=$(ip6tables -vnL INPUT --line-number | sed 1,2d | sed -n "/${shadowsocksport}/=" | sort -r)
    for ipset_index in $ipset_indexs; do
      ip6tables -D INPUT $ipset_index >/dev/null 2>&1
    done
  fi
  LOGGER 删除iptables完成 >> $LOG_FILE
}
add_ipset(){
  #创建名为gfwlist，格式为iphash的集合
  ipset -N $dnsmasq_gfw_ipset hash:ip timeout 300
  ipset -N $dnsmasq_gfw_ipset6 hash:ip family inet6 timeout 300
  add_cidr_proxy
  LOGGER "ipset 建立完成" >> $LOG_FILE
}
rm_ipset(){
  LOGGER 删除ipset开始 >> $LOG_FILE
  ipset -F $dnsmasq_gfw_ipset >/dev/null 2>&1 && ipset -X $dnsmasq_gfw_ipset >/dev/null 2>&1
  ipset -F $dnsmasq_gfw_ipset6 >/dev/null 2>&1 && ipset -X $dnsmasq_gfw_ipset6 >/dev/null 2>&1
  ipset -F $gfw_cidr_ipset >/dev/null 2>&1 && ipset -X $gfw_cidr_ipset >/dev/null 2>&1
  ipset -F $gfw_cidr_ipset6 >/dev/null 2>&1 && ipset -X $gfw_cidr_ipset6 >/dev/null 2>&1
  LOGGER 删除ipset结束 >> $LOG_FILE
}
#开始添加需要走代理的ip-cidr
add_cidr_proxy(){
  download_res_if_need
  if [ -f "$ipcidr_file" ]; then
    ipset -R < $ipcidr_file
    LOGGER "远程ip-cidr处理完成 << $ipcidr_file" >> $LOG_FILE
  else
    LOGGER "！！ip-cidr文件不存在, 未导入ip-cidr代理规则" >> $LOG_FILE
    return 1
  fi
}
download_res_if_need(){
  #强制下载，或者文件不存在时下载
  force_download=$1
  if [ -n "$force_download" ] || [ ! -f "$gfw_file" ]; then
    remote_gfw_conf="$remote_gfw_conf_lite"
    if [ "$clashg_gfw_file" = "gfw_file_full" ]; then
        remote_gfw_conf="$remote_gfw_conf_full"
    fi
    #github增加代理
    local remote_gfw_url_tmp=$(get_direct_url "${remote_gfw_conf}")
    LOGGER "开始下载dnsmasq gfwlist: ${gfw_file}.tmp 下载地址: ${remote_gfw_url_tmp}" >> $LOG_FILE
    curl ${CURL_OPTS} -o "${gfw_file}.tmp" "$remote_gfw_url_tmp"
    if [ -z "$(tail "${gfw_file}.tmp" | grep "$dnsmasq_gfw_ipset")" ]; then
        LOGGER "${gfw_file}.tmp 下载失败" >> $LOG_FILE
        return 1
    fi
    mv "${gfw_file}.tmp" ${gfw_file}
    LOGGER "dnsmasq gfwlist下载完成" >> $LOG_FILE
  fi
  if [ -n "$force_download" ] || [ ! -f "$ipcidr_file" ]; then
    local remote_proxy_url_tmp=$(get_direct_url "${remote_proxy_cidr}")
    LOGGER "开始下载ip-cidr: $ipcidr_file 下载地址: ${remote_proxy_url_tmp}" >> $LOG_FILE
    curl ${CURL_OPTS} -o "$ipcidr_file" "$remote_proxy_url_tmp"
    if [ -z "$(tail $ipcidr_file | grep "$gfw_cidr_ipset")" ]; then
        LOGGER "$ipcidr_file 下载失败" >> $LOG_FILE
        return 1
    fi
    LOGGER "ip-cidr下载完成" >> $LOG_FILE
  fi
}

#挂载gfwlist
add_dnsmasq_gfwlist(){
  download_res_if_need
  ln -snf $gfw_file /jffs/configs/dnsmasq.d/clashg_gfw.conf
  LOGGER "gfwlist软链已经添加完成" >> $LOG_FILE
}

rm_dnsmasq_gfwlist(){
  rm -rf /jffs/configs/dnsmasq.d/clashg_gfw.conf
}

prepare_start(){
  add_ipset
  add_dnsmasq_gfwlist
  add_nat
  restart_dnsmasq
  add_cron
  enable_tfo
}
prepare_stop(){
  rm_dnsmasq_gfwlist
  restart_dnsmasq
  rm_nat
  rm_ipset
  rm_all_cron
}
restart_dnsmasq(){
  dnsmasqpid=$(pidof dnsmasq)
  LOGGER "重启前dnsmasq进程：$dnsmasqpid" >> $LOG_FILE
  service restart_dnsmasq >/dev/null 2>&1
  sleep 1s
#  usleep 500000 #500ms
  dnsmasqpid=$(pidof dnsmasq)
#  procs=0
#	for d in $dnsmasqpid; do
#		procs=$(($procs+1))
#	done
  LOGGER "重启后dnsmasq进程：$dnsmasqpid" >> $LOG_FILE
}

start_clash(){
  LOGGER "启动Clash程序" >> $LOG_FILE
  if [ ! -e "$clashg_dir/cache.db" ]; then
    touch /tmp/cache.db 2>&1 &
    ln -s /tmp/cache.db $clashg_dir/cache.db
  fi
  $clashg_dir/clash -d $clashg_dir -f $clash_file 1> /tmp/clashg_run.log  2>&1 &
  LOGGER "启动Clash程序完毕，Clash启动日志位置：/tmp/clashg_run.log" >> $LOG_FILE
  #检查clash进程
  LOGGER "默认检查日志延迟时间:3秒" >> $LOG_FILE
  sleep 3s

  if [ ! -z "$(pidof clash)" -a ! -z "$(netstat -anp | grep clash)" -a ! -n "$(grep "Parse config error" /tmp/clashg_run.log)" ] ; then
    LOGGER "Clash 进程启动成功！(PID: $(pidof clash))"
  else
    LOGGER "Clash 进程启动失败！请检查配置文件是否存在问题，即将退出" >> $LOG_FILE
    LOGGER "Clash 进程启动失败！请查看日志检查原因" >> $LOG_FILE
    LOGGER "失败原因：" >> $LOG_FILE
    error1=$(cat /tmp/clashg_run.log | grep -oE "Parse config error.*")
    error2=$(cat /tmp/clashg_run.log | grep -oE "clashconfig.sh.*")
    error3=$(cat /tmp/clashg_run.log | grep -oE "illegal instruction.*")
    error4=$(cat /tmp/clashg_run.log | grep -n "level=error" | head -1 | grep -oE "msg=.*")
    if [ -n "$error1" ]; then
      LOGGER $error1 >> $LOG_FILE
    elif [ -n "$error2" ]; then
      LOGGER $error2 >> $LOG_FILE
    elif [ -n "$error3" ]; then
      LOGGER $error3 >> $LOG_FILE
      LOGGER "clash二进制故障，请重新上传" >> $LOG_FILE
    elif [ -n "$error4" ]; then
      LOGGER $error4 >> $LOG_FILE
    fi
    LOGGER "2s后停止clash：" >> $LOG_FILE
    sleep 2s
    prepare_stop
    stop_clash
  fi
}

stop_clash(){
  clash_process=$(pidof clash)
  if [ -n "$clash_process" ]; then
    LOGGER "关闭Clash进程, pid:$clash_process" >> $LOG_FILE
    killall clash >/dev/null 2>&1
    kill -9 "$clash_process" >/dev/null 2>&1
  fi
}


add_cron_job(){
  local job_name=$1
  local job_cron=$2
  local job_cmd=$3
  if [ -n "${job_name}" ] && [ -n "${job_cron}" ] && [ -n "${job_cmd}" ] && [ -z "$(cru l | grep "$job_name")" ]; then
    LOGGER "添加定时任务: ${job_name} ${job_cron} ${job_cmd}" >> $LOG_FILE
    cru a "${job_name}" "${job_cron}" "${job_cmd}"
  fi
  cru l |grep "${job_name}" >> $LOCK_FILE
}

del_cron_job() {
  local job_name=$1
  if [ -n "$(cru l | grep "$job_name")" ]; then
    LOGGER "删除定时任务: ${job_name}" >> $LOG_FILE
    cru d "$job_name"
  fi
  cru l |grep "${job_name}" >> $LOCK_FILE
}

##增加
add_cron(){
  #rule
  if [ -z "${clashg_update_rule_cron_base64}" ]; then
    del_cron_job clashg_update_rule_cron
  else
    clashg_update_rule_cron=$(echo -n ${clashg_update_rule_cron_base64} | base64_decode)
    add_cron_job clashg_update_rule_cron "${clashg_update_rule_cron}" "/koolshare/scripts/clashg_control.sh -1 update_rule" >> $LOG_FILE
  fi
  LOGGER "定时任务添加完成" >> $LOG_FILE
}
#删除全部
rm_all_cron(){
  del_cron_job clashg_update_rule_cron
  LOGGER "定时任务清理完成" >> $LOG_FILE
}

enable_tfo(){
  if [ "$inbound_tfo" == "true" -a -f "/proc/sys/net/ipv4/tcp_fastopen" ]; then
    fastopen_status=$(cat /proc/sys/net/ipv4/tcp_fastopen | xargs echo -n)
    if [ "$fastopen_status" -ne "3" -a "$fastopen_status" -ne "2" ]; then
      echo 3 > /proc/sys/net/ipv4/tcp_fastopen
      LOGGER "已经配置系统TFO参数" >> $LOG_FILE
    fi
  fi
}

apply() {
  if [ ! -f "$clash_file" ]; then
    LOGGER "clash配置文件$clash_file不存在，请编辑并保存配置文件！！！！！！！！" >> $LOG_FILE
    return 1
  fi
  set_lock
	# now stop first
  LOGGER "======================= ClashG ========================" >> $LOG_FILE
  LOGGER "---------------------- 重启dnsmasq,清除iptables+ipset+gfw规则 --------------------------" >> $LOG_FILE
  prepare_stop
  LOGGER "---------------------- 重启dnsmasq,清除iptables+ipset+gfw规则 结束 --------------------------" >> $LOG_FILE
  clash_process=$(pidof clash)
  if [ -z "$clash_process" ]; then
    LOGGER "" >> $LOG_FILE
    LOGGER "---------------------- 启动ClashG ------------------------" >> $LOG_FILE
    start_clash
    LOGGER "---------------------- 启动ClashG 结束 ------------------------" >> $LOG_FILE
  else
    LOGGER "---------------------- clash 进程已经存在(PID: $clash_process)，如需重启请执行关闭操作之后在执行开启操作 ------------------------" >> $LOG_FILE
  fi
  LOGGER ""
  LOGGER "--------------------- 创建相关分流相关配置 开始------------------------" >> $LOG_FILE
  prepare_start
  LOGGER "--------------------- 创建相关分流相关配置 结束------------------------" >> $LOG_FILE
  auto_start
  LOGGER "" >> $LOG_FILE

  LOGGER "" >> $LOG_FILE
  LOGGER "恭喜！开启ClashG成功！" >> $LOG_FILE
  LOGGER "" >> $LOG_FILE
  LOGGER "如果不能科学上网，请刷新设备dns缓存，或者等待几分钟再尝试" >> $LOG_FILE
  LOGGER "" >> $LOG_FILE
  unset_lock
}

case $ACTION in
start)
  LOGGER "开始启动ClashG" >> $LOG_FILE
  apply
  LOGGER "启动ClashG完成" >> $LOG_FILE
	;;
start_nat)
  LOGGER "网络变化处理ClashG相关配置" >> $LOG_FILE
  set_lock
  prepare_stop
  prepare_start
  unset_lock
  LOGGER "网络变化处理ClashG相关配置完成" >> $LOG_FILE
  ;;
stop)
  set_lock
  prepare_stop
  stop_clash
  LOGGER
  LOGGER "停止clashG" >> $LOG_FILE
  LOGGER
  unset_lock
	;;
update_dns_ipset_rule)
  set_lock
  LOGGER "更新规则开始下载资源" >> $LOG_FILE
  download_res_if_need "true"
  LOGGER "下载完成,重启Clashg或者重启dnsmasq(仅域名规则)后生效" >> $LOG_FILE
  unset_lock
  ;;
out_restart_dnsmasq)
  set_lock
  LOGGER "开始重启dnsmasq" >> $LOG_FILE
  restart_dnsmasq
  LOGGER "重启dnsmasq完成" >> $LOG_FILE
  unset_lock
  ;;
esac
