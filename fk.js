/*************************************
项目名称：翻咔
下载地址：
更新日期：2024-02-27
脚本作者：@anyeyey
使用声明：地图展示用户头像
**************************************

[rewrite_local]
^https:\/\/api\.finka\.cn\/vas\/nearby\/v2 url script-response-body https://raw.githubusercontent.com/Sanguine-00/ProxyRlue/main/fk.js
[mitm]
hostname = api.finka.cn
*************************************/
var anye = JSON.parse($response.body);
anye.coverExperiment = 0;
var list = anye.data.list;
for (var i=0;i<list.length;i++){ 
    list[i].hide = false;
}
$done({body : JSON.stringify(anye)});
