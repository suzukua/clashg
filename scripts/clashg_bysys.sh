#!/bin/sh

# 用于系统事件触发后回调

source /koolshare/scripts/base.sh

clashg_dir=/koolshare/clashg

alias echo_date='echo 【$(date +%Y年%m月%d日\ %X)】:'
mkdir -p /tmp/clashg
LOG_FILE=/tmp/clashg/log.txt
rm -rf $LOG_FILE
echo "" > $LOG_FILE

http_response "$1"

get(){
	a="$(echo $(dbus get $1))"
	echo $a
}

case $ACTION in
start)
  if [ "$clashg_enable" == "on" ]; then
    sh $clashg_dir/clashconfig.sh start
    echo 1
  fi
	;;
start_nat)
  if [ "$clashg_enable" == "on" ]; then
    sh $clashg_dir/clashconfig.sh start_nat
    echo 1
  fi
	;;
esac