<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
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
    <!-- 固件核心脚本保持同步加载，保证 state.js 等内部依赖与加载顺序不被破坏 -->
    <script language="JavaScript" type="text/javascript" src="/js/jquery.js"></script>
    <script language="JavaScript" type="text/javascript" src="/state.js"></script>
    <script language="JavaScript" type="text/javascript" src="/help.js"></script>
    <script language="JavaScript" type="text/javascript" src="/general.js"></script>
    <script language="JavaScript" type="text/javascript" src="/popup.js"></script>
    <script type="text/javascript" language="JavaScript" src="/js/table/table.js"></script>
    <script type="text/javascript" language="JavaScript" src="/client_function.js"></script>
    <script type="text/javascript" src="/res/softcenter.js"></script>
    <style type="text/css">
        .FormTable {
            margin-top: 15px;
        }

        .clashg_tab_panel {
            display: none;
        }

        .clashg_tab_panel.FormTable {
            margin-top: 0;
        }

        .tabs {
            margin-top: 15px;
            margin-bottom: 0;
            position: relative;
            z-index: 2;
            white-space: nowrap;
        }

        .tabs .tab {
            display: inline-block;
            min-width: 72px;
            height: 30px;
            line-height: 28px;
            padding: 0 10px;
            margin: 0 1px 0 0;
            border: 1px solid #1f2729;
            border-bottom: 0;
            border-radius: 0;
            background-color: #2f3a3e;
            background-image: none;
            background: linear-gradient(to bottom, #4c595d 0%, #2b3336 100%);
            color: #ffffff;
            font-family: Arial, Helvetica, Microsoft Yahei UI, sans-serif;
            font-size: 12px;
            font-weight: bold;
            text-align: center;
            text-decoration: none;
            text-shadow: 0 1px 0 rgba(0, 0, 0, 0.45);
            cursor: pointer;
            outline: none;
            box-sizing: border-box;
            vertical-align: bottom;
            overflow: visible;
            box-shadow: none;
            appearance: none;
            -webkit-appearance: none;
            -moz-appearance: none;
        }

        .tabs .tab:hover {
            background-color: #364043;
            background-image: none;
            background: linear-gradient(to bottom, #58676b 0%, #323b3e 100%);
        }

        .tabs .tab.active {
            background-color: #4d595d;
            background-image: none;
            background: #4d595d;
            position: relative;
            z-index: 3;
        }

        #loadingIcon {
            display: none;
            position: fixed;
            top: 50%;
            left: 50%;
            width: 88px;
            height: 88px;
            margin-left: -44px;
            margin-top: -44px;
            padding: 20px;
            box-sizing: border-box;
            background: rgba(38, 46, 49, 0.92);
            border: 1px solid #6b8fa3;
            z-index: 2000;
        }

        #copy_info {
            display: none;
            position: fixed;
            bottom: 20px;
            left: 50%;
            transform: translateX(-50%);
            z-index: 2001;
            color: #ffc800;
            font-size: 24px;
            white-space: nowrap;
        }

        .clashg_hint {
            color: #93b1b6;
            font-size: 11px;
            line-height: 1.6;
            margin-top: 2px;
        }
        </style>
    <script type="text/javascript">
        var dbus = {};
        var _responseLen;
        var noChange = 0;
        var $j = $;

        var clash_bord_info = {}

        function init() {
	        show_menu(menu_hook);
            var savedTab = "btn_default_tab";
            try { savedTab = localStorage.getItem('clashg_actived_tab') || "btn_default_tab"; } catch(e) {}
            document.getElementById(savedTab).click();
            get_dbus_data();
        }
        function menu_hook() {
            tabtitle[tabtitle.length - 1] = new Array("", "MerlinClash", "__INHERIT__");
            tablink[tablink.length - 1] = new Array("", "Module_clashg.asp",  "NULL");
        }

        // [优化2] async: false → async: true
        // 同步 XHR 会完全阻塞浏览器主线程（包括 UI 渲染），是最严重的首屏卡顿根源
        function get_dbus_data() {
            $j.ajax({
                type: "GET",
                url: "/_api/clashg",
                async: true,
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
                    var trs = "";
                    var statusGroups=data.status_info
                    for(var i = 0; i < statusGroups.length; i++) {
                      var statusGroupName = statusGroups[i].key
                      var th="<th><label>" + statusGroupName + "</label></th>"
                      var td = "<td>" + statusGroups[i].value + "</td>";
                      trs += "<tr js_add>" + th + td + "</tr>"
                    }
                    $j("tr[js_add]").remove()
                    if ($j("#status_tools_row").length) {
                        $j(trs).insertBefore($j("#status_tools_row"));
                    } else {
                        $j("#menu_default").append(trs);
                    }
                }
            })
        }

        function show_loading() {
            $j("#Loading").show();
            $j("#loadingIcon").show();
        }

        function hide_loading() {
            $j("#Loading").hide();
            $j("#loadingIcon").hide();
        }

        function conf2obj() {
            E("clashg_enable").checked = (dbus["clashg_enable"] == 'on');
            E("clashg_update_rule_cron").value = Base64.decode(dbus["clashg_update_rule_cron"] || "");
            E("clashg_gfw_file").value = dbus["clashg_gfw_file"];
            E("clashg_open_port").value = dbus["clashg_open_port"] || "";
            E("clashg_open_proto").value = dbus["clashg_open_proto"] || "both";
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
            show_loading();
            $j.ajax({
                type: "POST",
                cache: false,
                url: "/_api/",
                data: JSON.stringify(postData),
                dataType: "json",
                success: function(response) {
                    hide_loading();
                    if (response.result == id) {
                        if (response.status == "ok") {
                            if (flag && flag == "0") {
                                // 查看执行过程日志
                            } else if (flag && flag == "1") {
                                refreshpage(3);
                            } else if (flag && flag == "2") {
                                // 什么也不做...
                            }
                            var resp_data = response.data;
                            if (callback) {
                                setTimeout(function() {
                                    callback(resp_data);
                                }, 1000);
                            }
                        } else if (flag && flag == "1") {
                            refreshpage(3);
                        } else if (flag && flag == "2") {
                            if (callback) {
                                setTimeout(function() {
                                    callback();
                                }, 1000);
                            }
                        } else {
                            if (callback) {
                                setTimeout(function() {
                                    callback();
                                }, 1000);
                            }
                        }
                    }
                },
                // [优化3] 补全 error 回调：网络失败时隐藏 loading 图标，否则会一直转
                error: function() {
                    hide_loading();
                }
            });
        }

        function show_result(message, duration) {
            if (!duration) duration = 1000;
            $j('#copy_info').text(message);
            $j('#copy_info').fadeIn(100);
            $j('#copy_info').css('display', 'inline-block');
            setTimeout(function() {
                $j('#copy_info').fadeOut(1000);
            }, duration);
        }

        function show_status() {
            $j.ajax({
                url: '/_temp/clashglog.txt',
                type: 'GET',
                async: true,
                cache: false,
                dataType: 'text',
                success: function(response) {
                    var logBackup = E("clash_log_backup");
                    logBackup.value = response.replace("XU6J03M6", " ");
                    logBackup.scrollTop = logBackup.scrollHeight;
                    if (response.lastIndexOf("XU6J03M6\n") === response.length - ("XU6J03M6\n").length) {
                        return true;
                    }
                    if (_responseLen == response.length) {
                        noChange++;
                    } else {
                        // [优化4] 内容有变化时重置计数器
                        // 原来缺少此行：一旦积累超过1000次无变化后轮询永久停止，
                        // 即使之后日志继续输出也不会再刷新
                        noChange = 0;
                    }
                    if (noChange <= 1000) {
                        // [优化5] setTimeout 传函数引用而非字符串
                        // 字符串形式需要 eval 解析，性能较差
                        setTimeout(show_status, 500);
                    }
                    _responseLen = response.length;
                },
                error: function() {
                    // [同上优化5] 统一改为函数引用
                    setTimeout(show_status, 500);
                }
            });
        }

        function switch_tabs(evt, tab_id) {
            var i, tabcontent, tablinks;
            tabcontent = document.getElementsByClassName("clashg_tab_panel");
            for (i = 0; i < tabcontent.length; i++) {
                tabcontent[i].style.display = "none";
            }
            tablinks = document.getElementsByClassName("tab");
            for (i = 0; i < tablinks.length; i++) {
                tablinks[i].className = tablinks[i].className.replace(" active", "");
            }
            document.getElementById(tab_id).style.display = "table";
            evt.currentTarget.className += " active";
            try { localStorage.setItem('clashg_actived_tab', evt.currentTarget.id); } catch(e) {}
        }

        function reload_Soft_Center() {
            location.href = "/Module_Softcenter.asp";
        }

        /*********************主要功能逻辑模块实现**************/
        function apply_action(action, flag, callback, ret_data) {
            if (!action) {
                return;
            }
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
            apply_action("start", "0", function(data) {
                // [优化6] data 空值防护：接口异常时 data 可能为 null/undefined，
                // 直接赋值给 dbus 再调用 conf2obj() 会报错
                if (data) {
                    dbus = data;
                    conf2obj();
                }
                getStatus();
            }, {
                "clashg_enable": dbus["clashg_enable"]
            });
        }

        function switch_service() {
            if (document.getElementById('clashg_enable').checked) {
                dbus["clashg_enable"] = "on";
                service_start();
            } else {
                dbus["clashg_enable"] = "off";
                service_stop();
            }
        }

        function apply_open_port() {
            var port = document.getElementById('clashg_open_port').value.trim();
            var proto = document.getElementById('clashg_open_proto').value;
            if (!port || isNaN(port) || parseInt(port) <= 0 || parseInt(port) > 65535) {
                show_result("请输入有效的端口号(1-65535)!", 2000);
                return;
            }
            apply_action("apply_open_port", "2", function() {
                show_result("公网访问规则已应用!");
            }, {
                "clashg_open_port": port,
                "clashg_open_proto": proto
            });
        }

        function clear_open_port() {
            document.getElementById('clashg_open_port').value = '';
            apply_action("apply_open_port", "2", function() {
                show_result("公网访问规则已清除!");
            }, {
                "clashg_open_port": "",
                "clashg_open_proto": ""
            });
        }

        function update_dns_ipset_rule(){
            apply_action("update_dns_ipset_rule", "0", null);
        }
        function update_gfw_file(){
            dbus["clashg_gfw_file"] = document.getElementById("clashg_gfw_file").value
            apply_action("save_clashg_gfw_file", "2", null, {
                            "clashg_gfw_file": dbus["clashg_gfw_file"]
                        });
        }
        function reset_config_file() {
            apply_action("reset_config_file", "2", function() {
                show_result("重置配置文件成功!");
                switch_edit_filecontent()
            });
            $j("#clash_config_content").attr("readonly", true);
        }

        function save_config_content() {
            var content = $j("#clash_config_content").val();
            if (content == "") {
                return false;
            }
            var base64_content = Base64.encode(content);
            apply_action("save_config_file", "2", function() {
                show_result("保存文件内容成功!");
                switch_edit_filecontent()
            }, {"clashg_yaml_edit_content": base64_content});
            $j("#clash_config_content").attr("readonly", true);
        }

        function edit_config_content() {
            $j("#clash_config_content").attr("readonly", false);
            $j("#clash_config_content").focus();
            show_result("开始编辑文件!")
        }

        function set_edit_content(data) {
            var filecontent = Base64.decode(data);
            if (filecontent == "") {
                console.log("文件内容为空");
                return false;
            }
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
                    console.log("文件内容为空");
                    return false;
                }
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
            apply_action("update_cron " + cron_name, "0", null, dbus_tmp);
        }

        function copyURI(evt) {
            evt.preventDefault();
            E("clashg_geoip_url").value=evt.target.getAttribute('href')
        }

        // [优化7] 空值防护：getStatus() 未返回前 clash_bord_info 为空对象，
        // clash_bord_info.ip 等字段均为 undefined，会打开无效 URL
        function open_clash_board(board_url){
            if (!clash_bord_info || !clash_bord_info.ip || !clash_bord_info.port) {
                show_result("面板信息尚未加载，请稍候...", 2000);
                return;
            }
            if(!board_url){
                board_url = 'http://' + clash_bord_info.ip + ':' + clash_bord_info.port + '/ui/xd/#/setup';
            }
            window.open(board_url + '?http=true&hostname=' + clash_bord_info.ip + '&port=' + clash_bord_info.port + '&secret=' + clash_bord_info.secret, '_blank');
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
            <td height="430" valign="top">
                <div id="tabMenu" class="submenuBlock"></div>
                <table width="98%" border="0" align="left" cellpadding="0" cellspacing="0">
                    <tr>
                        <td valign="top">
                            <table width="760px" border="0" cellpadding="5" cellspacing="0" class="FormTitle" id="FormTitle">
                                <tbody>
                                    <tr>
                                        <td bgcolor="#4D595D" valign="top">
                                            <div>&nbsp;</div>
                                            <div class="formfonttitle">Clash版科学上网工具
                                            </div>
                                            <div style="float:right; width:15px; height:25px;margin-top:-20px">
                                                <img id="return_btn" onclick="reload_Soft_Center();" align="right" style="cursor:pointer;position:absolute;margin-left:-30px;margin-top:-25px;" title="返回软件中心" src="/images/backprev.png" onMouseOver="this.src='/images/backprevclick.png'" onMouseOut="this.src='/images/backprev.png'"></img>
                                            </div>
                                            <div style="margin:10px 0 10px 5px;" class="splitLine"></div>
                                            <div class="formfontdesc" style="margin-bottom:0px;">ClashG 特性：dnsmasq 分流国外，即使本应用挂掉对国内访问毫无影响，可最大程度修改 mihomo 配置。</div>
                    <!-- Tab菜单 -->
                                            <div class="tabs">
                                                <button type="button" id="btn_default_tab" class="tab" onclick="switch_tabs(event, 'menu_default');getStatus();">主面板</button>
                                                <button type="button" id="btn_config_tab" class="tab" onclick="switch_tabs(event, 'menu_config');switch_edit_filecontent();">在线编辑</button>
                                                <button type="button" id="btn_option_tab" class="tab" onclick="switch_tabs(event, 'menu_options');">资源配置</button>
                                                <button type="button" id="btn_log_tab" class="tab" onclick="switch_tabs(event, 'menu_log');show_status()">日志信息</button>
                                                <button type="button" id="btn_run_config_tab" class="tab" onclick="switch_tabs(event, 'menu_run_config');load_run_config_file()">运行配置</button>
<!--                        <button id="btn_help_tab" class="tab" onclick="switch_tabs(event, 'menu_help');">帮助信息</button>-->
                                            </div>

                    <!-- 主面板 Tab -->
                    <table id="menu_default" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable clashg_tab_panel">
                        <thead>
                            <tr>
                                <td colspan="2">主面板</td>
                            </tr>
                        </thead>
                        <tr>
                            <th>
                                <label>开启ClashG服务</label>
                            </th>
                            <td>
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
                        <tr id="status_tools_row">
                            <td colspan="2" align="center">
                                <div id="status_tools" style="padding: 15px 0 5px 0; text-align: center;">
                                    <input type="button" class="button_gen" title="下载xd资源文件到ui目录进行访问，参考mihomo文档" onclick="open_clash_board();" value="metacubex(xd)控制面板">
                                </div>
                            </td>
                        </tr>
                    </table>

                    <!-- 资源配置 Tab -->
                    <table id="menu_options" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable clashg_tab_panel">
                        <thead>
                            <tr>
                                <td colspan="2">资源配置</td>
                            </tr>
                        </thead>
                        <tr>
                            <th>GFW列表选择</th>
                            <td>
                                <select id="clashg_gfw_file" class="input_option" style="width: 67%;">
                                    <option value="gfw_file_full">GFW全</option>
                                    <option value="gfw_file_lite" selected>GFW精简</option>
                                </select>
                                <input type="button" class="button_gen" onclick="update_gfw_file()" style="margin-left: 5px;" value="保存">
                            </td>
                        </tr>
                        <tr>
                            <th><label title="更新频率不宜过高，一周更新一次即可。" class="hintstyle">gfw和ipcidr文件</label></th>
                            <td>
                                预设gfw和ipcidr规则，暂不支持修改，参考
                                <a style="color: chartreuse;" href="https://github.com/zhudan/gfwlist2dnsmasq" target="_blank" rel="noopener noreferrer">Github地址</a>
                                <input type="button" class="button_gen" onclick="update_dns_ipset_rule()" style="margin-left: 5px;" value="更新">
                            </td>
                        </tr>
                        <tr>
                            <th><label title="定时更新，下一次重启clashg生效" class="hintstyle">定时更新gfw、ipcidr</label></th>
                            <td>
                                <input type="text" style="width: 65%;" class="input_6_table" id="clashg_update_rule_cron" placeholder="15 7 * * 6  (清空后保存即可删除)">
                                <input type="button" class="button_gen" onclick="update_cron('clashg_update_rule_cron')" style="margin-left: 5px;" value="保存">
                            </td>
                        </tr>
                        <tr>
                            <th>
                                <label title="开放指定端口的公网入站访问(IPV4/IPV6)" class="hintstyle">开放公网访问</label>
                                <div class="clashg_hint">建议仅开放 Clash 实际监听端口</div>
                            </th>
                            <td>
                                <input type="text" id="clashg_open_port" style="width: 75px;" placeholder="端口" class="input_6_table" maxlength="5">
                                <select id="clashg_open_proto" class="input_option" style="width: 105px;">
                                    <option value="both">TCP+UDP</option>
                                    <option value="tcp">TCP</option>
                                    <option value="udp">UDP</option>
                                </select>
                                <input type="button" class="button_gen" onclick="apply_open_port()" style="margin-left: 5px;" value="应用">
                                <input type="button" class="button_gen" onclick="clear_open_port()" style="margin-left: 5px;" value="清除">
                                <div class="clashg_hint">支持 IPv4 / IPv6，修改后立即生效</div>
                            </td>
                        </tr>
                    </table>

                    <!-- 在线编辑配置文件内容 -->
                    <table id="menu_config" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable clashg_tab_panel">
                        <thead>
                            <tr>
                                <td colspan="2">在线编辑</td>
                            </tr>
                        </thead>
                        <tr>
                            <td colspan="2">
                                <div class="formfontdesc" style="margin-bottom:10px;">文件内容（保存之后手动重启才生效）</div>
                                <textarea id="clash_config_content" readonly="true" rows="20" class="textarea_ssh_table" style="width: 98%; white-space: pre;" title="为了防止误编辑，默认为只读，点击编辑后才可修改哦！&#010;快捷键Ctrl+S: 保存.&#010;快捷键Ctrl+E: 编辑.&#010;快捷键Ctrl+R: 重新加载。"></textarea>
                            </td>
                        </tr>
                        <tr>
                            <td colspan="2">
                                <input type="button" class="button_gen" onclick="edit_config_content()" value="编辑">
                                <input type="button" class="button_gen" onclick="save_config_content()" style="margin-left: 5px;" value="保存">
                                <input type="button" class="button_gen" onclick="reset_config_file()" style="margin-left: 5px;" value="恢复安装时刻配置">
                            </td>
                        </tr>
                    </table>

                    <!-- 日志 Tab -->
                    <table id="menu_log" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable clashg_tab_panel">
                        <thead>
                            <tr>
                                <td colspan="2">日志信息</td>
                            </tr>
                        </thead>
                        <tr>
                            <td colspan="2">
                                <p style="text-align: left; color: rgb(32, 252, 32); font-size: 18px; padding-top: 10px; padding-bottom: 10px;">日志信息</p>
                                <textarea rows="20" style="width: 98%; white-space: pre;" wrap="off" readonly="readonly" id="clash_log_backup" class="textarea_ssh_table"></textarea>
                            </td>
                        </tr>
                    </table>

                    <!-- 当前运行配置 Tab -->
                    <table id="menu_run_config" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable clashg_tab_panel">
                        <thead>
                            <tr>
                                <td colspan="2">运行配置</td>
                            </tr>
                        </thead>
                        <tr>
                            <td colspan="2">
                                <div class="formfontdesc" style="margin-bottom:10px;">文件内容</div>
                                <textarea id="clash_run_config_content" readonly="true" rows="20" class="textarea_ssh_table" style="width: 98%; white-space: pre;"></textarea>
                            </td>
                        </tr>
                    </table>
                    <img id="loadingIcon" src="/images/loading.gif" />
                    <label id="copy_info"></label>

                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
    <div id="footer"></div>
</body>
</html>
