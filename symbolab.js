/** Symbolab 解锁高级功能 (需登录) */

***************************
QuantumultX:

# Symbolab 解锁订阅

[rewrite_local]
^https?:\/\/scibug\.com\/appleSubscriptionValidate$ url script-response-body script-path=https://raw.githubusercontent.com/Sanguine-00/ProxyRlue/main/symbolab.js
[mitm]
hostname = scibug.com

***************************
Surge4 or Loon:

[Script]
http-response ^https?:\/\/scibug\.com\/appleSubscriptionValidate requires-body=1,max-size=0,script-path=https://raw.githubusercontent.com/Sanguine-00/ProxyRlue/main/symbolab.js

[MITM]
hostname = scibug.com

**************************/




var body = $response.body;
var obj = JSON.parse(body);

obj.data["valid"] = true;
obj.data["hasUserConsumedAppleFreeTrial"] = false;
obj.data["isCurrentlyInFreeTrial"] = false;
obj.data["newlyAssociated"] = false;

body = JSON.stringify(obj);
$done({body});
