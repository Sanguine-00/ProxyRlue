
if (!$response.body) {
    // 有undefined的情况
    console.log(`$response.body为undefined:${url}`);
    $done({});
}

let body = JSON.parse($response.body);

console.log(`body:${$response.body}`);

body.res.hs. collectTime = "2022-12-20 19:10:00"

console.log(`body:${$response.body}`);

body = JSON.stringify(body);
$done({
    body
});