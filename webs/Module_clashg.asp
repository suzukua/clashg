<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<html xmlns:v>

<head>
    <meta http-equiv="X-UA-Compatible" content="IE=Edge" />
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <meta HTTP-EQUIV="Pragma" CONTENT="no-cache">
    <meta HTTP-EQUIV="Expires" CONTENT="-1">
    <link rel="shortcut icon" href="images/favicon.png">
    <link rel="icon" href="images/favicon.png">
    <title>科学上网工具-ClashG(gfwlist分流)</title>
    <link rel="stylesheet" type="text/css" href="index_style.css" />
    <link rel="stylesheet" type="text/css" href="form_style.css" />
    <link rel="stylesheet" type="text/css" href="usp_style.css" />
    <link rel="stylesheet" type="text/css" href="css/element.css">
    <link rel="stylesheet" type="text/css" href="res/softcenter.css">
    <script type="text/javascript" src="/state.js"></script>
    <script type="text/javascript" src="/popup.js"></script>
    <script type="text/javascript" src="/help.js"></script>
    <script type="text/javascript" src="/js/jquery.js"></script>
    <script type="text/javascript" src="/general.js"></script>
    <script type="text/javascript" language="JavaScript" src="/js/table/table.js"></script>
    <script type="text/javascript" language="JavaScript" src="/client_function.js"></script>
    <script type="text/javascript" src="/res/softcenter.js"></script>
    <style type="text/css">
        .clash_basic_info{
            display: block;
            text-align: left;
            font-size: 13px;
            font-family: 'Courier New', Courier, monospace;
        }

        .switch_field {
            display: table-cell;
            float: left;
        }

        .input_text {
            width: 95%;
            font-family: Courier New, Courier, mono;
            background: #3b4c50;
            color: #FFFFFF;
        }

        .apply_gen {
            width: 95%;
            margin-top: 0px;
        }

        .FormTable {
            display: none;
            width: 100%;
            animation: fadeEffect 1s; /* Fading effect takes 1 second */
        }

        .tabs {
            overflow: hidden;
            border: 1px rgb(132, 132, 132);
        }
        button.tab.active {
            background-color: #387387;
        }

        /* Go from zero to full opacity */
        @keyframes fadeEffect {
            from {opacity: 0;}
            to {opacity: 1;}
        }

        .copyToClipboard {
            color: red !important;
        }

        td.hasButton {
            text-align: center;
        }

        td {
            text-align: left;
        }

        .hintstyle {
            cursor: help;
        }

        .formfonttitle {
            display: block;
            text-align: left;
        }

        .softcenterRetBtn {
            float: right;
            cursor: pointer;
            margin-top: -20px;
            content: url('/images/backprev.png');
        }

        .softcenterRetBtn:hover {
            content: url('/images/backprevclick.png');
        }
        </style>
    <script type="text/javascript">
        var dbus = {};
        var _responseLen;
        var noChange = 0;
        var $j = jQuery.noConflict();

        var clash_bord_info = {}

        function init() {
	        show_menu(menu_hook);
            document.getElementById(localStorage.getItem('clashg_actived_tab') || "btn_default_tab").click();
            get_dbus_data();
        }
        function menu_hook() {
            tabtitle[tabtitle.length - 1] = new Array("", "MerlinClash", "__INHERIT__");
            tablink[tablink.length - 1] = new Array("", "Module_clashg.asp",  "NULL");
        }
        function get_dbus_data() {
            $j.ajax({
                type: "GET",
                url: "/_api/clashg",
                async: false,
                success: function(data) {
                    dbus = data.result[0];
                    conf2obj();
                }
            });
        }

        function getStatus(){
            apply_action("get_status", 2, function(data){
                if(data && data.board_info){
                    clash_bord_info = data.board_info
                }
                if(data && data.status_info){
//                     #[{key:"name1",value:"value"},{key:"name1",value:"value"}]
                    var trs = "";
                    var statusGroups=data.status_info
                    for(let i = 0; i < statusGroups.length; i++) {
                      var statusGroupName = statusGroups[i].key
                      var th="<th><label>" + statusGroupName + "</label></th>"
                      var td = "<td>" + statusGroups[i].value + "</td>";
                      trs += "<tr js_add>" + th + td + "</tr>"
                    }
                    $j("tr[js_add]").remove()
                    $j("#menu_default").append(trs);
                }
            })
        }

        function conf2obj() {
            E("clashg_enable").checked = (dbus["clashg_enable"] == 'on');
            E("clashg_mixed_port_status").checked = (dbus["clashg_mixed_port_status"] == 'on');
            E("clashg_update_rule_cron").value = Base64.decode(dbus["clashg_update_rule_cron"] || "");
            E("clashg_gfw_file").value = dbus["clashg_gfw_file"];
        }

        //提交任务方法,实时日志显示
        // flag: 0:提交任务并查看日志，1:提交任务3秒后刷新页面, 2:提交任务后无特殊操作(可指定callback回调函数)
        function post_dbus_data(script, arg, obj, flag, callback) {
            if(flag == 0){
                setTimeout(show_status, 200);
            }
            var id = parseInt(Math.random() * 100000000);
            var postData = {
                "id": id,
                "method": script,
                "params": [arg],
                "fields": obj
            };
            $j("#loadingIcon").show();
            $j.ajax({
                type: "POST",
                cache: false,
                url: "/_api/",
                data: JSON.stringify(postData),
                dataType: "json",
                success: function(response) {
                    $j("#loadingIcon").hide();
                    if (response.result == id) {
                        if (response.status == "ok") {
                            if (flag && flag == "0") {
                                // 查看执行过程日志
                                // show_status();
                            } else if (flag && flag == "1") {
                                // 页面刷新操作
                                refreshpage(3);
                            } else if (flag && flag == "2") {
                                // 什么也不做...
                            }
                            // 动态获取数据模式: JSON数据保存在 response.data 变量中
                            // data内部数据使用方式: resp_data.key1 , resp_data.key2 , resp_data.key3 ...
                            var resp_data = response.data;
                            if (callback) {
                                setTimeout(function() {
                                    callback(resp_data);
                                }, 1000);
                            }
                        } else if (flag && flag == "1") {
                            // 页面刷新操作
                            refreshpage(3);
                        } else if (flag && flag == "2") {
                            //continue;
                            if (callback) {
                                setTimeout(function() {
                                    callback();
                                }, 1000);
                            }
                        } else {
                            // show_status();
                            if (callback) {
                                setTimeout(function() {
                                    callback();
                                }, 1000);
                            }
                        }
                    }
                }
            });
        }

        // function test_res() {
        //     apply_action("test_res")
        // }
        // 显示动态结果消息
        function show_result(message, duration) {
            if (!duration) duration = 1000;
            $j('#copy_info').text(message);
            $j('#copy_info').fadeIn(100);
            $j('#copy_info').css('display', 'inline-block');
            setTimeout(() => {
                $j('#copy_info').fadeOut(1000);
            }, duration);
        }

        function show_status() {
            if(localStorage.getItem('clashg_actived_tab') != 'btn_log_tab'){
                $j("#logMsg").show();//非日志tab才展示
            }

            $j.ajax({
                url: '/_temp/clashglog.txt',
                type: 'GET',
                async: true,
                cache: false,
                dataType: 'text',
                success: function(response) {
                    var logBackup = E("clash_log_backup");
                    logBackup.value = response.replace("XU6J03M6", " ");
                    logBackup.scroll({ top: logBackup.scrollHeight, left: 0, behavior: "smooth" })
                    if(localStorage.getItem('clashg_actived_tab') != 'btn_log_tab'){
                        var logMsg = E("clash_log_msg");
                        logMsg.value = logBackup.value;
                        logMsg.scrollTop = logMsg.scrollHeight;
                    }
                    if (response.endsWith("XU6J03M6\n")) {
                        return true;
                    }
                    if (_responseLen == response.length) {
                        noChange++;
                    }
                    if (noChange <= 1000) {
                        //重新加载
                        setTimeout("show_status();", 500);
                    }
                    _responseLen = response.length;
                },
                error: function() {
                    setTimeout("show_status();", 500);
                }
            });
        }


        function switch_tabs(evt, tab_id) {
            // Declare all variables
            var i, tabcontent, tablinks;

            // Get all elements with class="tabcontent" and hide them
            tabcontent = document.getElementsByClassName("FormTable");
            for (i = 0; i < tabcontent.length; i++) {
                tabcontent[i].style.display = "none";
            }

            // Get all elements with class="tablinks" and remove the class "active"
            tablinks = document.getElementsByClassName("tab");
            for (i = 0; i < tablinks.length; i++) {
                tablinks[i].className = tablinks[i].className.replace(" active", "");
            }

            // Show the current tab, and add an "active" class to the button that opened the tab
            document.getElementById(tab_id).style.display = "inline-table";
            evt.currentTarget.className += " active";
            $j("#logMsg").hide();//切换关闭日志窗口
            localStorage.setItem('clashg_actived_tab', evt.currentTarget.id);
        }

        function reload_Soft_Center() {
            location.href = "/Module_Softcenter.asp";
        }

        /*********************主要功能逻辑模块实现**************/
        // flag: 0:提交任务并查看日志，1:提交任务3秒后刷新页面, 2:提交任务后无特殊操作(可指定callback回调函数)
        function apply_action(action, flag, callback, ret_data) {
            if (!action) {
                return;
            }
            // 如果只需要某个参数，就没必要提交所有dbus数据，参数传递过多也是会有速度影响的。
            if (!ret_data) {
                ret_data = dbus;
            }
            post_dbus_data("clashg_control.sh", action, ret_data, flag, callback);
        }

        function service_stop() {
            apply_action("stop", "0", getStatus, {
                "clashg_enable": dbus["clashg_enable"]
            });
        }

        function service_start() {
            // 由于 start 需要先确保执行成功后再返回执行结果,因此先设置等待状态图片显示，然后再执行 start 操作。
            apply_action("start", "0", function(data) {
                // 更新dbus数据中的 clashg_enable 状态 on/off
                dbus = data;
                conf2obj();
                getStatus()
            }, {
                "clashg_enable": dbus["clashg_enable"]
            });
        }

        function switch_service() {
            $j("#loadingIcon").show();
            if (document.getElementById('clashg_enable').checked) {
                dbus["clashg_enable"] = "on";
                service_start();
            } else {
                dbus["clashg_enable"] = "off";
                service_stop();
            }
        }
        function switch_mixed_port_mode(){
            if (document.getElementById('clashg_mixed_port_status').checked) {
                dbus["clashg_mixed_port_status"] = "on";
            } else {
                dbus["clashg_mixed_port_status"] = "off";
            }
            apply_action("set_mixed_port_status", "2", null, {
                "clashg_mixed_port_status": dbus["clashg_mixed_port_status"]
            });
        }

        function update_dns_ipset_rule(){
            // $j("#loadingIcon").show();
            apply_action("update_dns_ipset_rule", "0", null);
        }

        // 恢复配置信息的压缩包文件
        function reset_config_file() {
            apply_action("reset_config_file", "2", function() {
                show_result("重置配置文件成功!");
                switch_edit_filecontent()//重新获取配置文件
            });
            // 设置readonly属性为true
            $j("#clash_config_content").attr("readonly", true);
        }

        // 保存config文件内容
        function save_config_content() {
            var content = $j("#clash_config_content").val();
            if (content == "") {
                return false;
            }
            var base64_content = Base64.encode(content);
            //临时保存到dbus，保存完毕删除
            apply_action("save_config_file", "2", function() {
                show_result("保存文件内容成功!");
                switch_edit_filecontent()//重新获取配置文件
            }, {"clashg_yaml_edit_content": base64_content});
            // 设置readonly属性为true
            $j("#clash_config_content").attr("readonly", true);
        }

        // 编辑config文件内容
        function edit_config_content() {
            $j("#clash_config_content").attr("readonly", false);
            $j("#clash_config_content").focus();
            show_result("开始编辑文件!")
        }


        function set_edit_content(data) {
             // 解码base64格式的 data.clash_edit_filecontent
            var filecontent = Base64.decode(data);
            if (filecontent == "") {
                // 文件内容为空
                console.log("文件内容为空");
                return false;
            }
            // 设置当前textarea的内容为 file_content
            $j("#clash_config_content").val(filecontent);
            show_result("配置文件加载成功!", 1000);
        }

        function switch_edit_filecontent() {
            apply_action("get_config_file", "2", function(data){
                set_edit_content(data)
            });
        }
        function load_run_config_file(){
            apply_action("get_run_config_file", "2", function(data){
                var filecontent = Base64.decode(data);
                if (filecontent == "") {
                    // 文件内容为空
                    console.log("文件内容为空");
                    return false;
                }
                // 设置当前textarea的内容为 file_content
                $j("#clash_run_config_content").val(filecontent);
                show_result("配置文件加载成功!", 1000);
            });
        }

        function update_cron(cron_name){
            var dbus_tmp={};
            if(document.getElementById(cron_name).value){
                dbus_tmp[cron_name] = Base64.encode(document.getElementById(cron_name).value);
            } else {
                dbus_tmp[cron_name] = ""
            }
            // $j("#loadingIcon").show();
            apply_action("update_cron " + cron_name, "0", null, dbus_tmp);
        }

        function copyURI(evt) {
            evt.preventDefault();
            E("clashg_geoip_url").value=evt.target.getAttribute('href')
        }
        function open_clash_board(board_url){
            window.open(board_url + '#/?host=' + clash_bord_info.ip + '&port=' + clash_bord_info.port + '&secret=' + clash_bord_info.secret, '_blank');
        }
        function open_yacd_board(board_url){
            window.open(board_url + '?hostname=' + clash_bord_info.ip + '&port=' + clash_bord_info.port + '&secret=' + clash_bord_info.secret, '_blank');
        }
    </script>
</head>

<body onload="init();">
    <div id="TopBanner"></div>
    <div id="Loading" class="popup_bg"></div>
    <iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>
    <!-- 主要页面内容定义-->
    <table class="content" align="center" cellpadding="0" cellspacing="0">
        <tr>
            <td width="17">&nbsp;</td>
            <td valign="top" width="202">
                <div id="mainMenu"></div>
                <div id="subMenu"></div>
            </td>
            <td valign="top">
                <div id="tabMenu" class="submenuBlock"></div>
                <div class="apply_gen FormTitle">
                    <div class="clash_top" style="padding-top: 20px;">
                        <div class="formfonttitle" ><b>Clash</b>版科学上网工具
                            <img id="return_btn" onclick="reload_Soft_Center();" class="softcenterRetBtn" title="返回软件中心""></img>
                        </div>
                    </div>
                    <div class="clash_basic_info">
                        <!--插件特点-->
                        <p style="color: rgb(229, 254, 2);">
                            <b><a style="color: rgb(0, 255, 60);font-size: 16px;" href="#">ClashG特性</a></b>:dnsmasq分流国外，对国内域名毫无影响，国外域名借助Meta Clash的sniff国外解析<br/>
                        </p>
                        <hr>
                    </div>
                    <!-- Tab菜单 -->
                    <div class="tabs">
                        <button id="btn_default_tab" class="tab" onclick="switch_tabs(event, 'menu_default');getStatus();">主面板</button>
                        <button id="btn_config_tab" class="tab" onclick="switch_tabs(event, 'menu_config');switch_edit_filecontent();">在线编辑</button>
                        <button id="btn_option_tab" class="tab" onclick="switch_tabs(event, 'menu_options');">资源配置</button>
                        <button id="btn_log_tab" class="tab" onclick="switch_tabs(event, 'menu_log');show_status()">日志信息</button>
                        <button id="btn_run_config_tab" class="tab" onclick="switch_tabs(event, 'menu_run_config');load_run_config_file()">运行配置</button>
<!--                        <button id="btn_help_tab" class="tab" onclick="switch_tabs(event, 'menu_help');">帮助信息</button>-->
                    </div>

                    <!-- 默认设置Tab -->
                    <table id="menu_default" class="FormTable">
                        <thead width="100%">
                            <tr>
                                <td colspan="2">ClashG - 设置面板</td>
                            </tr>
                        </thead>
                        <tr>
                            <th>
                                <label>开启ClashG服务</label>
                            </th>
                            <td colspan="2">
                                <div class="switch_field">
                                    <label for="clashg_enable">
                                        <input id="clashg_enable" onclick="switch_service();" class="switch" type="checkbox" style="display: none;">
                                        <div class="switch_container">
                                            <div class="switch_bar"></div>
                                            <div class="switch_circle transition_style"></div>
                                        </div>
                                    </label>
                                </div>
                            </td>
                        </tr>
                    </table>
                    <!-- 资源配置 -->
                    <table id="menu_options" class="FormTable">
                        <thead>
                            <tr>
                                <td colspan="2">ClashG - 资源配置</td>
                            </tr>
                        </thead>
                        <tr>
                            <th>
                                <label title="更新频率不同过高,一周更新一次即可." class="hintstyle">gfw和ipcidr文件</label>
                            </th>
                            <td>
                                预设gfw和ipcidr规则,暂不支持修改<a style="color:chartreuse" href="https://github.com/zhudan/gfwlist2dnsmasq" target="_blank" rel="noopener noreferrer">Github地址</a>
                                 <button type="button" class="button_gen" onclick="update_dns_ipset_rule()" href="javascript:void(0);">更新</button>
                            </td>
                        </tr>
                        <tr>
                            <th>
                                <label title="定时更新,下一次重启clashg生效" class="hintstyle">定时更新gfw、ipcidr</label>
                            </th>
                            <td>
                                <input style="width: 65%;" type="text" class="input_6_table" id="clashg_update_rule_cron" placeholder="29 7 * * * 清空则删除定时任务，记得点保存">
                                <button type="button" class="button_gen" onclick="update_cron('clashg_update_rule_cron')" href="javascript:void(0);">保存</button>
                            </td>
                        </tr>
                        <tr>
                            <th>
                                <label title="默认关闭，开放Shadownsocks公网访问(IPV4/IPV6)">公网开放Shadownsocks</label>
                            </th>
                            <td colspan="2">
                                <div class="switch_field">
                                    <label for="clashg_mixed_port_status">
                                        <input id="clashg_mixed_port_status" onclick="switch_mixed_port_mode();" class="switch" type="checkbox" style="display: none;">
                                        <div class="switch_container">
                                            <div class="switch_bar"></div>
                                            <div class="switch_circle transition_style"></div>
                                        </div>
                                    </label>
                                </div>
                            </td>
                        </tr>
                    </table>
                    <!-- 在线编辑配置文件内容 -->
                    <table id="menu_config" class="FormTable">
                        <thead>
                            <tr>
                                <td colspan="3">ClashG - 配置文件编辑 【保存之后手动重启才生效】</td>
                            </tr>
                        </thead>
                        <tr>
                            <td colspan="2">
                                <div style="display: block;text-align: center; font-size: 14px; color:rgb(0, 201, 0);">文件内容</div>
                                <textarea id="clash_config_content" readonly="true" rows="20" class="textarea_ssh_table" style="width: 98%; white-space: pre;" title="为了防止误编辑，默认为只读，点击编辑后才可修改哦！&#010;快捷键Ctrl+S: 保存.&#010;快捷键Ctrl+E: 编辑.&#010;快捷键Ctrl+R: 重新加载。"></textarea>
                            </td>
                        </tr>
                        <tr>
                            <td colspan="2">
                                <button type="button" class="button_gen" onclick="edit_config_content()" href="javascript:void(0);">编辑</button> &nbsp;&nbsp;&nbsp;&nbsp;
                                <button type="button" class="button_gen" onclick="save_config_content()" href="javascript:void(0);">保存</button>
                                <button type="button" class="button_gen" onclick="reset_config_file()" href="javascript:void(0);">恢复安装时刻配置</button>
                            </td>
                        </tr>
                    </table>
                    <table id="menu_log" class="FormTable">
                        <thead>
                            <tr>
                                <td colspan="2">ClashG - 日志</td>
                            </tr>
                        </thead>
                        <tr id="logBackup">
                            <td colspan="2">
                                <p style="text-align: left; color: rgb(32, 252, 32); font-size: 18px;padding-top: 10px;padding-bottom: 10px;">日志信息</p>
                                <textarea rows="20" style="width:98%;white-space: pre;" wrap="off" readonly="readonly" id="clash_log_backup" class="textarea_ssh_table"></textarea>
                            </td>
                        </tr>
                    </table>
                    <!-- 当前配置 -->
                    <table id="menu_run_config" class="FormTable">
                        <thead>
                            <tr>
                                <td colspan="3">ClashG - 当前运行配置</td>
                            </tr>
                        </thead>
                        <tr>
                            <td colspan="2">
                                <div style="display: block;text-align: center; font-size: 14px; color:rgb(0, 201, 0);">文件内容</div>
                                <textarea id="clash_run_config_content" readonly="true" rows="20" class="textarea_ssh_table" style="width: 98%;white-space: pre;"></textarea>
                            </td>
                        </tr>
                    </table>
                    <!--打开 Clash控制面板-->
                    <div id="status_tools " style="margin-top: 25px; padding-bottom: 20px;">
                        <button type="button" class="button_gen" id="clash_yacd_ui" onclick="open_clash_board('https://clash.metacubex.one/');">metacubex控制面板</button>
                        <button type="button" class="button_gen" id="clash_yacd_ui" onclick="open_yacd_board('https://d.metacubex.one/');">metacubex(xd)控制面板</button>
                    </div>

                    <div>
                        <div style="height: 60px;margin-top:10px; ">
                            <div><img id="loadingIcon" style="display:none; " src="/images/loading.gif"></div>
                            <!-- 显示动态消息 -->
                            <label id="copy_info" style="display: none;color:#ffc800;font-size: 24px; "></label>
                        </div>
                    </div>

                    <div id="logMsg" style="display: none;">
                        <div>显示日志信息</div>
                        <textarea rows="20" wrap="off" readonly="readonly" id="clash_log_msg" class="textarea_ssh_table" style="width:98%;white-space: pre;"></textarea>
                    </div>

                </div>
            </td>
            <div class="author-info"></div>
        </tr>
    </table>
    <div id="footer"></div>
</body>
</html>
