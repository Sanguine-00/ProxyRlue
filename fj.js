/*************************************
项目名称：翻咔
下载地址：
更新日期：2024-01-16
脚本作者：@anyeyey
使用声明：⚠️仅供参考，🈲转载与售卖！
解锁会员功能 隐藏我的活跃时间.隐藏距离.隐藏访问足迹.悄悄查看消息    设置 隐私设定内查看
**************************************

[rewrite_local]
^https:\/\/api\.finka\.cn\/vas\/nearby\/v2 url script-response-body https://raw.githubusercontent.com/Sanguine-00/ProxyRlue/main/fk.js
[mitm]
hostname = api.finka.cn
*************************************/
var anye = JSON.parse($response.body);
var list = anye.data.list;
for (var i=0;i<list.length;i++){ 
    list[i].hide = false;
}
$done({body : JSON.stringify(anye)});
