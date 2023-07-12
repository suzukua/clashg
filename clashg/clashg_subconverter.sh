#!/bin/sh
source /koolshare/scripts/base.sh
source /koolshare/clashg/base.sh

failed_warning_clash(){
  LOGGER "订阅下载失败！！！" >> $LOG_FILE
  sc_process=$(pidof subconverter)
  if [ -n "$sc_process" ]; then
    LOGGER 关闭subconverter进程... >> $LOG_FILE
    killall subconverter >/dev/null 2>&1
  fi
  LOGGER "===================================================================" >> $LOG_FILE
  exit 1
}

generate_random_user_agent() {
  local random_index
  local max_index=9
  local random_bytes
  random_bytes=$(tr -dc '0-9' < /dev/urandom | head -c2 | sed 's/^0*//')
  random_index=$((random_bytes % (max_index+1)))
  local user_agent
  case $random_index in
    0) user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" ;;
    1) user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.107 Safari/537.36" ;;
    2) user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0" ;;
    3) user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Edge/92.0.902.55 Safari/537.36" ;;
    4) user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.212 YaBrowser/21.6.1.289 Yowser/2.5 Safari/537.36" ;;
    5) user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64; Trident/7.0; rv:11.0) like Gecko" ;;
    6) user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36" ;;
    7) user_agent="Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" ;;
    8) user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.212 Safari/537.36" ;;
    9) user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.131 Safari/537.36" ;;
  esac
  echo "$user_agent"
}
start_online_update_hnd(){
  links="http://127.0.0.1:25500/sub?${subconverter_args}"
  LOGGER "subconverter进程：$(pidof subconverter)" >> $LOG_FILE
  LOGGER "即将开始转换，需要一定时间，请等候处理" >> $LOG_FILE
  sleep 1s
  LOGGER "生成订阅链接：$links" >> $LOG_FILE

  #wget下载文件
  #wget --no-check-certificate -t3 -T30 -4 -O /tmp/upload/$upname "$links"
  UA=$(generate_random_user_agent)
  LOGGER "使用常规网络下载..." >> $LOG_FILE
  curl -4sSk --user-agent "$UA" --connect-timeout 30 "$links" > $clash_sub_file_tmp
  LOGGER "配置文件下载完成 ${clash_sub_file_tmp}" >> $LOG_FILE
  #虽然为0但是还是要检测下是否下载到正确的内容
  if [ "$?" == "0" ];then
    #下载为空...
    if [ -n "$(cat $clash_sub_file_tmp | grep proxies:)" ] && [ -z "$(cat $clash_sub_file_tmp | grep proxy-groups:\ ~)" ]; then
      LOGGER "使用curl下载成功，但是内容不包含节点或者不包含proxy-groups，尝试更换wget进行下载: $links"	>> $LOG_FILE
      rm -rf $clash_sub_file_tmp
      UA=$(generate_random_user_agent)
      wget --user-agent="$UA" --no-check-certificate -t3 -T30 -4 -O $clash_sub_file_tmp "$links"
    fi
    LOGGER "检查文件完整性" >> $LOG_FILE
    if [ -z "$(cat $clash_sub_file_tmp | grep proxies:)" ]; then
      LOGGER "订阅clash配置文件错误！没有包含节点" >> $LOG_FILE
      failed_warning_clash
    fi
    cp $clash_sub_file_tmp $clash_sub_file
  else
    LOGGER "下载超时" >> $LOG_FILE
    failed_warning_clash
  fi
}

#merge(){
#  LOGGER "合并配置到${clash_file}" >> $LOG_FILE
#  #自定义配置文件不存在则从原厂配置copy一份
#  if [ ! -f $clash_edit_file ]; then
#    cp $clash_ro_file $clash_edit_file
#  fi
#  $clashg_dir/yq merge $clash_edit_file $clash_sub_file > $clash_file
#  LOGGER "合并配置完成" >> $LOG_FILE
#}

convert(){
  LOGGER "subconverter转换处理" >> $LOG_FILE
  $clashg_dir/subconverter >/dev/null 2>&1 &
  start_online_update_hnd >> $LOG_FILE
  sc_process=$(pidof subconverter)
  if [ -n "$sc_process" ]; then
    LOGGER "关闭subconverter进程..." >> $LOG_FILE
    killall subconverter >/dev/null 2>&1
  fi
}
#  target=$clashtarget&new_name=true&url=$merlinc_link&insert=false&config=${urlinilink}&include=$include&exclude=$exclude&append_type=$appendtype&emoji=$emoji&udp=$udp&fdn=$fdn&sort=$sort&scv=$scv&tfo=$tfo
subconverter_args=$1
convert
