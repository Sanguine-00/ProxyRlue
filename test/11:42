var http = require("http");
var url = require("url");

http.createServer(function(req,res){
 console.log("start request:",req.url);

 var option = url.parse(req.url);
 option.headers = req.headers;

 var proxyRequest = http.request(option, function(proxyResponse){

 
 proxyResponse.on("data",function(chunk){
 console.log("proxyResponse length",chunk.length);
 });
 proxyResponse.on("end",function(){
 console.log("proxyed request ended");
 res.end();
 })

 res.writeHead(proxyResponse.statusCode,proxyResponse.headers);
 });

 
 req.on("data",function(chunk){
 console.log("in request length:",chunk.length);
 proxyRequest.write(chunk,"binary");
 })

 req.on("end",function(){
 console.log("original request ended");
 proxyRequest.end();
 })

}).listen(65081);
