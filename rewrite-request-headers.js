/**
 * @fileoverview Example of HTTP rewrite of request header.
 *
 * @supported Quantumult X (v1.0.5-build188)
 *
 * [rewrite_local]
 * ^http://example\.com/resource9/ url script-request-header sample-rewrite-request-header.js
 */

// $request.scheme, $request.method, $request.url, $request.path, $request.headers

var modifiedHeaders = $request.headers;
modifiedHeaders['Host'] = 'lt.wapzt.189.cn/amdc.alipay.com:1082';
modifiedHeaders['X-Online-Host'] = '\t\t';
modifiedHeaders['X-T5-Auth'] = 'YTY0Nzlk';
modifiedHeaders['Proxy-Connection'] = 'Keep-Alive';
modifiedHeaders['User-Agent'] = 'baiduboxapp';

// var scheme = $request.scheme;
// if (scheme.includes('https')) {
//
// }
console.log(modifiedHeaders);
console.log('done');

$done({headers: modifiedHeaders});
// $done({path : modifiedPath});
// $done({}); // Not changed.
