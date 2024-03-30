/*************************************
项目名称：乐游无锡
下载地址：
更新日期：2024-02-27
脚本作者：
使用声明：
**************************************

[rewrite_local]
^https:\/\/www\.taihumingzhuwx\.com\/api\/trip-scard-core\/bus\/card\/products url script-response-body https://raw.githubusercontent.com/Sanguine-00/ProxyRlue/main/lywx.js
[mitm]
hostname = www.taihumingzhuwx.com
*************************************/
var bodyRes = JSON.parse($response.body);
bodyRes.result[0].isOpen = true;
bodyRes.result[0].cardNo = '6032020170589030';
bodyRes.result[0].cardpCode = '00001';

$done({body : JSON.stringify(bodyRes)});
