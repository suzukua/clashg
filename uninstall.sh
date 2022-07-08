#! /bin/sh

#########################################################
# Clash script for AM380 merlin firmware
# Writen by Awkee (next4nextjob(at)gmail.com) 
# Website: https://vlike.work
#########################################################

KSHOME="/koolshare"
source ${KSHOME}/scripts/base.sh

LOGGER() {
    logger -s -t "$(date +%Y年%m月%d日%H:%M:%S):clash" "$@"
}

app_name="clashg"

# 清理旧文件，升级情况需要
remove_files() {
    LOGGER 清理旧文件
    LOGGER "执行命令：rm -rf /koolshare/${app_name}"
    rm -rf /koolshare/${app_name}

    LOGGER "执行命令： rm -rf /koolshare/webs/Module_${app_name}.asp"
    rm -rf /koolshare/webs/Module_${app_name}.asp

    rm -rf /koolshare/res/icon-${app_name}.png


    LOGGER "执行命令： rm -f /koolshare/init.d/S??${app_name}.sh"
    rm -rf /koolshare/init.d/S??${app_name}.sh

}


remove_env() {
    # 清理环境变量, 相当于清理数据库，避免无意义数据遗留在数据库中
    LOGGER "清理环境变量信息:"
    for vname in $(dbus list softcenter_module_${app_name}_|cut -d "=" -f1)
    do
        dbus remove ${vname}
    done

    for vname in $(dbus list clashg_ | cut -d "=" -f1)
    do
        dbus remove ${vname}
    done
    LOGGER "清理环境变量信息完成"
}

LOGGER "开始卸载插件啦！"

sh /koolshare/${app_name}/clashconfig.sh stop

remove_files
remove_env
LOGGER "卸载完成啦！一切都归于尘土，哦不！是垃圾站！"

LOGGER "执行命令：rm -rf /koolshare/scripts/${app_name}_*"
rm -rf /koolshare/scripts/${app_name}_*
# delete myself
rm -f /koolshare/scripts/uninstall_${app_name}.sh

