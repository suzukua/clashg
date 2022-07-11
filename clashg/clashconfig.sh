#!/bin/sh

source /koolshare/scripts/base.sh
source /koolshare/clashg/base.sh

clashg_update_geoip_cron_base64=$(get clashg_update_geoip_cron)
clashg_update_rule_sub_restart_cron_base64=$(get clashg_update_rule_sub_restart_cron)
clashg_mixed_port_status=$(get clashg_mixed_port_status)

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
	LOGGER "判断是否创建开自启动"
	[ ! -L "/koolshare/init.d/S99clashg.sh" ] && ln -sf /koolshare/scripts/clashg_control.sh /koolshare/init.d/S99clashg.sh
	[ ! -L "/koolshare/init.d/N99clashg.sh" ] && ln -sf /koolshare/scripts/clashg_control.sh /koolshare/init.d/N99clashg.sh
}

add_nat(){
  if [ "${clashg_mixed_port_status}" == "on" ]; then
    LOGGER "开启mixed-port: ${mixedport}公网访问" >> $LOG_FILE
    iptables -I INPUT -p tcp --dport $mixedport -j ACCEPT
    ip6tables -I INPUT -p tcp --dport $mixedport -j ACCEPT
  fi
  #匹配gfwlist中ip的nat流量均被转发到clash端口
#  iptables -t nat -A PREROUTING -p tcp -m set --match-set $dnsmasq_gfw_ipset dst -j REDIRECT --to-port "$proxy_port"
#  iptables -t nat -A PREROUTING -p tcp -m set --match-set $gfw_cidr_ipset dst -j REDIRECT --to-port "$proxy_port"
## tproxy模式
  ip rule add fwmark 10 table 100
  ip -f inet route add local 0.0.0.0/0 dev lo table 100
  iptables -t mangle -I PREROUTING -p tcp -m set --match-set $dnsmasq_gfw_ipset dst -j TPROXY --on-port $tproxy_port --tproxy-mark 10
  iptables -t mangle -I PREROUTING -p udp -m set --match-set $dnsmasq_gfw_ipset dst -j TPROXY --on-port $tproxy_port --tproxy-mark 10
  iptables -t mangle -I PREROUTING -p tcp -m set --match-set $gfw_cidr_ipset dst -j TPROXY --on-port $tproxy_port --tproxy-mark 10
  iptables -t mangle -I PREROUTING -p udp -m set --match-set $gfw_cidr_ipset dst -j TPROXY --on-port $tproxy_port --tproxy-mark 10
  LOGGER "iptables 建立完成" >> $LOG_FILE
}
rm_nat(){
#  iptables -t nat -D PREROUTING -p tcp -m set --match-set $dnsmasq_gfw_ipset dst -j REDIRECT --to-port "$proxy_port"
#  iptables -t nat -D PREROUTING -p tcp -m set --match-set $gfw_cidr_ipset dst -j REDIRECT --to-port "$proxy_port"
	LOGGER 删除iptables开始 >> $LOG_FILE
#	ipset_indexs=$(iptables -t nat -vnL PREROUTING --line-number  | sed 1,2d | sed -n "/${proxy_port}/=" | sort -r)
#  for ipset_index in $ipset_indexs; do
#    iptables -t nat -D PREROUTING $ipset_index >/dev/null 2>&1
#  done

  #tproxy模式
  ip rule del fwmark 10 table 100 >/dev/null 2>&1
  ip route del local 0.0.0.0/0 dev lo table 100 >/dev/null 2>&1
	ipset_indexs=$(iptables -t mangle -vnL PREROUTING --line-number  | sed 1,2d | sed -n "/${tproxy_port}/=" | sort -r)
  for ipset_index in $ipset_indexs; do
    iptables -t mangle -D PREROUTING $ipset_index >/dev/null 2>&1
  done

	# 清理mixedport端口
	ipset_indexs=$(iptables -vnL INPUT --line-number | sed 1,2d | sed -n "/${mixedport}/=" | sort -r)
	for ipset_index in $ipset_indexs; do
		iptables -D INPUT $ipset_index >/dev/null 2>&1
	done
	ipset_indexs=$(ip6tables -vnL INPUT --line-number | sed 1,2d | sed -n "/${mixedport}/=" | sort -r)
	for ipset_index in $ipset_indexs; do
		ip6tables -D INPUT $ipset_index >/dev/null 2>&1
	done
	LOGGER 删除iptables完成 >> $LOG_FILE
}
add_ipset(){
  #创建名为gfwlist，格式为iphash的集合
  ipset -N $dnsmasq_gfw_ipset hash:ip timeout 1800
  add_cidr_proxy
  LOGGER "ipset 建立完成" >> $LOG_FILE
}
rm_ipset(){
  LOGGER 删除ipset开始 >> $LOG_FILE
  ipset -F $dnsmasq_gfw_ipset >/dev/null 2>&1 && ipset -X $dnsmasq_gfw_ipset >/dev/null 2>&1
  ipset -F $gfw_cidr_ipset >/dev/null 2>&1 && ipset -X $gfw_cidr_ipset >/dev/null 2>&1
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

# 更新Country.mmdb文件
update_geoip() {
  LOGGER "geo下载: 开始处理" >> $LOG_FILE
  local clashg_geoip_url=$1
  geoip_file="${clashg_dir}/Country.mmdb"
  geoip_file_new="${clashg_dir}/Country.mmdb.new"
  local geoip_url="https://raw.githubusercontent.com/Loyalsoldier/geoip/release/Country-only-cn-private.mmdb"
  if [ ! -z "$clashg_geoip_url" ] ; then
    geoip_url="$clashg_geoip_url"
  fi
  geoip_url=$(get_direct_url "${geoip_url}")
  LOGGER "geo开始下载: ${geoip_file_new}, 地址: ${geoip_url}" >> $LOG_FILE
  curl ${CURL_OPTS} -o "${geoip_file_new}" "${geoip_url}"
  if [ "$?" != "0" ] ; then
    LOGGER "下载 $geoip_file_new 文件失败! [${geoip_url}]" >> $LOG_FILE
    rm -rf $geoip_file_new
    return 1
  fi
  mv ${geoip_file} ${geoip_file}.bak
  mv ${geoip_file_new} ${geoip_file}
  LOGGER "「$geoip_file」文件更新成功!" >> $LOG_FILE
  LOGGER "文件大小变化[`du -h ${geoip_file}.bak|cut -f1`]=>[`du -h ${geoip_file}|cut -f1`]" >> $LOG_FILE
  rm ${geoip_file}.bak
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
  usleep 500000 #500ms
  dnsmasqpid=$(pidof dnsmasq)
#  procs=0
#	for d in $dnsmasqpid; do
#		procs=$(($procs+1))
#	done
	LOGGER "重启后dnsmasq进程：$dnsmasqpid" >> $LOG_FILE
}

start_clash(){
  LOGGER "启动Clash程序" >> $LOG_FILE
	$clashg_dir/clash -d $clashg_dir -f $clash_file 1> /tmp/clashg_run.log  2>&1 &
	LOGGER "启动Clash程序完毕，Clash启动日志位置：/tmp/clashg_run.log" >> $LOG_FILE
	#检查clash进程
	LOGGER "默认检查日志延迟时间:2秒" >> $LOG_FILE
  sleep 2s

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
    LOGGER "3s后停止clash：" >> $LOG_FILE
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
  if [ -z "${clashg_update_rule_sub_restart_cron_base64}" ]; then
    del_cron_job clashg_update_rule_sub_restart_cron
  else
    clashg_update_rule_sub_restart_cron=$(echo -n ${clashg_update_rule_sub_restart_cron_base64} | base64_decode)
    add_cron_job clashg_update_rule_sub_restart_cron "${clashg_update_rule_sub_restart_cron}" "/koolshare/scripts/clashg_control.sh -1 update_rule_sub_restart" >> $LOG_FILE
  fi
  #geo
  if [ -z "${clashg_update_rule_sub_restart_cron_base64}" ]; then
    del_cron_job clashg_update_geoip_cron
  else
    clashg_update_geoip_cron=$(echo -n ${clashg_update_geoip_cron_base64} | base64_decode)
    add_cron_job clashg_update_geoip_cron "${clashg_update_geoip_cron}" "/koolshare/scripts/clashg_control.sh -1 update_geoip" >> $LOG_FILE
  fi
  LOGGER "定时任务添加完成" >> $LOG_FILE
}
#删除全部
rm_all_cron(){
  del_cron_job clashg_update_rule_sub_restart_cron
  del_cron_job clashg_update_geoip_cron
  LOGGER "定时任务清理完成" >> $LOG_FILE
}

apply() {
  if [ ! -f "$clash_file" ]; then
      LOGGER "clash配置文件$clash_file不存在，请重新订阅！！！！！！！！" >> $LOG_FILE
      return 1
  fi
  set_lock
	# now stop first
	LOGGER ======================= ClashG ======================== >> $LOG_FILE
	LOGGER ---------------------- 重启dnsmasq,清除iptables+ipset规则 -------------------------- >> $LOG_FILE
	prepare_stop
	stop_clash
	LOGGER --------------------- 重启dnsmasq,清除iptables+ipset规则 结束------------------------ >> $LOG_FILE
	LOGGER "" >> $LOG_FILE
  LOGGER ---------------------- 启动ClashG ------------------------ >> $LOG_FILE
	start_clash
	LOGGER ""
	LOGGER --------------------- 创建相关分流相关配置 开始------------------------ >> $LOG_FILE
	prepare_start
	LOGGER --------------------- 创建相关分流相关配置 结束------------------------ >> $LOG_FILE
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
start|start_nat)
  LOGGER "开始启动ClashG" >> $LOG_FILE
	apply
	LOGGER "启动ClashG完成" >> $LOG_FILE
	;;
restart)
	LOGGER "开始重启ClashG" >> $LOG_FILE
	stop_clash
	start_clash
	LOGGER "重启ClashG完成" >> $LOG_FILE
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
  LOGGER "下载完成" >> $LOG_FILE
  unset_lock
  ;;
update_geoip)
  set_lock
  LOGGER 开始更新geo文件 >> $LOG_FILE
  update_geoip $2
  LOGGER 完成更新geo文件 >> $LOG_FILE
  unset_lock
  ;;
esac