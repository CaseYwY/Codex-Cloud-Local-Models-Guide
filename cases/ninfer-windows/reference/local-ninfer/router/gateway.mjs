// Loopback-only Codex router. Account credentials are never read from disk or logged.
import http from 'node:http';
import https from 'node:https';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import zlib from 'node:zlib';
import {fileURLToPath} from 'node:url';

const dir=path.dirname(fileURLToPath(import.meta.url));
const settings=JSON.parse(fs.readFileSync(path.join(dir,'settings.json'),'utf8'));
const cloudAgent=new https.Agent({keepAlive:true,...settings.cloud_proxy?{proxyEnv:{HTTPS_PROXY:settings.cloud_proxy,HTTP_PROXY:settings.cloud_proxy,NO_PROXY:'127.0.0.1,localhost'}}:{}});
const locals=JSON.parse(fs.readFileSync(path.join(dir,'../models.json'),'utf8')).models;
const localIds=new Set(locals.map(x=>x.slug));
const prefix='/backend-api/codex';
const counters={cloud:0,local:0,models:0,errors:0};
let recentCatalog=null;
const hop=new Set(['host','connection','content-length','transfer-encoding','keep-alive','upgrade','proxy-authorization','proxy-authenticate','te','trailer','x-codex-local-router-key']);
function json(res,status,data){res.writeHead(status,{'content-type':'application/json; charset=utf-8','cache-control':'no-store'});res.end(JSON.stringify(data));}
function auth(req){
 const a=Buffer.from(String(req.headers['x-codex-local-router-key']??'')),b=Buffer.from(settings.key);
 return a.length===b.length&&crypto.timingSafeEqual(a,b);
}
function localCredential(){
 const p=path.join(os.homedir(),'.config/opencode/opencode.json');
 const c=JSON.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,''));
 const h=c.providers?.['llama-wm']?.headers;
 const v=h?.Authorization??h?.authorization;
 if(typeof v!=='string'||!v.startsWith('Bearer '))throw new Error('local_credential_unavailable');
 return v;
}
function decoded(body,encoding){
 if(!encoding||encoding==='identity')return body;
 if(encoding==='gzip')return zlib.gunzipSync(body);
 if(encoding==='br')return zlib.brotliDecompressSync(body);
 if(encoding==='deflate')return zlib.inflateSync(body);
 if(encoding==='zstd'&&zlib.zstdDecompressSync)return zlib.zstdDecompressSync(body);
 throw new Error('unsupported_request_encoding');
}
function headersFor(req,local){
 const h={};for(const[k,v]of Object.entries(req.headers))if(!hop.has(k))h[k]=v;
 if(local){
  for(const k of Object.keys(h))if(k==='authorization'||k==='cookie'||k.startsWith('chatgpt-')||k.startsWith('openai-'))delete h[k];
  h.authorization=localCredential();delete h['content-encoding'];
 }
 return h;
}
function responseHeaders(h){const out={};for(const[k,v]of Object.entries(h))if(!hop.has(k))out[k]=v;return out;}
function cloudCatalog(req){
 if(recentCatalog&&Date.now()-recentCatalog.at<60000&&recentCatalog.account===req.headers['chatgpt-account-id'])return Promise.resolve(recentCatalog.data);
 return new Promise((resolve,reject)=>{
  const h=headersFor(req,false);delete h['if-none-match'];delete h['if-modified-since'];delete h['content-type'];delete h['content-encoding'];h['accept-encoding']='identity';h.accept='application/json';
  const u=new URL(req.url,'http://127.0.0.1');
  if(!u.searchParams.has('client_version'))u.searchParams.set('client_version','0.163.0-alpha.10.2');
  const call=https.request({hostname:'chatgpt.com',port:443,path:prefix+'/models'+u.search,method:'GET',headers:h,agent:cloudAgent},up=>{
   const chunks=[];up.on('data',x=>chunks.push(x));up.on('end',()=>{
    try{
     if(up.statusCode!==200)return reject(new Error('cloud_catalog_http_'+up.statusCode));
     const d=JSON.parse(decoded(Buffer.concat(chunks),up.headers['content-encoding']).toString('utf8'));
     if(!Array.isArray(d.models)||!d.models.some(x=>x.slug==='gpt-6.1-sol'))throw new Error('cloud_catalog_schema');
     const models=d.models.filter(x=>!localIds.has(x.slug));
     // Keep every upstream model and its metadata intact; append only local entries.
     const highest=Math.max(0,...models.map(x=>Number(x.priority)||0));
     const added=locals.map((x,i)=>({...x,priority:highest+100+i}));
     const merged={...d,models:[...models,...added]};
     const catalogPath=path.join(dir,'catalog-cache.json');
     const temporary=catalogPath+'.'+process.pid+'.'+crypto.randomBytes(6).toString('hex')+'.tmp';
     try {
      fs.writeFileSync(temporary,JSON.stringify(merged));
      fs.renameSync(temporary,catalogPath);
     } finally { try { fs.unlinkSync(temporary); } catch {} }
     counters.catalogRefreshes=(counters.catalogRefreshes??0)+1;
     recentCatalog={at:Date.now(),account:req.headers['chatgpt-account-id'],data:merged};resolve(merged);
    }catch(e){reject(e);}
   });
  });call.setTimeout(30000,()=>call.destroy(new Error('cloud_catalog_timeout')));call.on('error',reject);call.end();
 });
}
function proxy(req,res,body,local,suffix){
 const headers=headersFor(req,local);headers['content-length']=body.length;
 const options=local?{hostname:'127.0.0.1',port:7777,path:'/v1'+suffix,method:req.method,headers}:{hostname:'chatgpt.com',port:443,path:prefix+suffix,method:req.method,headers,agent:cloudAgent};
 const call=(local?http:https).request(options,up=>{
  res.writeHead(up.statusCode??502,responseHeaders(up.headers));up.pipe(res);
  up.on('error',()=>res.destroy());
 });
 call.setTimeout(600000,()=>call.destroy(new Error('upstream_timeout')));
 call.on('error',()=>{counters.errors++;if(!res.headersSent)json(res,502,{error:{message:local?'Local NInfer is unavailable at port 7777. Start its saved Manager profile.':'Cloud upstream connection failed.',type:'router_upstream_error'}});else res.destroy();});
 res.on('close',()=>{if(!res.writableFinished)call.destroy();});call.end(body);
}
const server=http.createServer(async(req,res)=>{
 try{
  // Browser origins cannot use this credential-bearing native-client endpoint.
  if(req.headers.origin)return json(res,403,{error:'browser_origin_not_allowed'});
  const url=new URL(req.url,'http://127.0.0.1');
  if(url.pathname==='/health'&&req.method==='GET')return json(res,200,{service:'codex-cloud-local-router',version:1,pid:process.pid,cloud:'chatgpt.com',local:'127.0.0.1:7777',counters});
  if(!auth(req)){
   counters.authRejected=(counters.authRejected??0)+1;
   counters.lastRejectedHasAccountAuth=typeof req.headers.authorization==='string';
   counters.lastRejectedHasRouterKey=typeof req.headers['x-codex-local-router-key']==='string';
   return json(res,401,{error:'router_auth_required'});
  }
  if(url.pathname===prefix+'/models'&&req.method==='GET'){
   counters.models++;
   const cache=path.join(dir,'catalog-cache.json');
   if(fs.existsSync(cache)){
    try{
     const saved=JSON.parse(fs.readFileSync(cache,'utf8'));
     if(!Array.isArray(saved.models)||!saved.models.some(x=>x.slug==='gpt-6.1-sol')||!saved.models.some(x=>x.slug==='ninfer-minsi'))throw new Error('invalid_cache');
     json(res,200,saved);
     cloudCatalog(req).catch(()=>{counters.catalogRefreshErrors=(counters.catalogRefreshErrors??0)+1;});
     return;
    }catch{}
   }
   try{return json(res,200,await cloudCatalog(req));}
   catch{
    if(fs.existsSync(cache))return json(res,200,JSON.parse(fs.readFileSync(cache,'utf8')));
    return json(res,502,{error:'cloud_catalog_unavailable_no_cache'});
   }
  }
  if(req.method!=='POST'||![prefix+'/responses',prefix+'/responses/compact'].includes(url.pathname))return json(res,404,{error:'route_not_found'});
  const chunks=[];let size=0;
  for await(const c of req){size+=c.length;if(size>128*1024*1024)return json(res,413,{error:'request_too_large'});chunks.push(c);}
  const raw=Buffer.concat(chunks);let plain,model;
  try{plain=decoded(raw,req.headers['content-encoding']);model=JSON.parse(plain.toString('utf8')).model;}catch{return json(res,400,{error:'invalid_model_request'});}
  const local=localIds.has(model);
  if(!local&&(typeof model!=='string'||!model.startsWith('gpt-')))return json(res,400,{error:'unknown_model'});
  counters[local?'local':'cloud']++;
  // The native picker reads its disk catalog; a cloud request refreshes it in
  // the background without making either the picker or inference wait for it.
  if(!local)cloudCatalog(req).catch(()=>{counters.catalogRefreshErrors=(counters.catalogRefreshErrors??0)+1;});
  proxy(req,res,local?plain:raw,local,url.pathname.slice(prefix.length)+url.search);
 }catch{counters.errors++;if(!res.headersSent)json(res,500,{error:'router_internal_error'});else res.destroy();}
});
server.requestTimeout=0;server.headersTimeout=60000;
server.listen(settings.port,'127.0.0.1',()=>{
 fs.writeFileSync(path.join(dir,'process.json'),JSON.stringify({pid:process.pid,port:settings.port,started_at:new Date().toISOString()}));
 process.stdout.write('Codex cloud/local router ready on loopback.\n');
});
server.on('error',()=>{process.stderr.write('Router could not bind its configured loopback port.\n');process.exitCode=1;});
