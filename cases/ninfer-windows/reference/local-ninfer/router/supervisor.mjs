import fs from 'node:fs';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const dir=path.dirname(fileURLToPath(import.meta.url));
const output=fs.openSync(path.join(dir,'gateway.log'),'a');
let retry=500;
function start(){
 const began=Date.now();
 const child=spawn(process.execPath,[path.join(dir,'gateway.mjs')],{cwd:dir,windowsHide:true,stdio:['ignore',output,output]});
 fs.writeFileSync(path.join(dir,'supervisor.json'),JSON.stringify({pid:process.pid,child_pid:child.pid,started_at:new Date().toISOString()}));
 child.on('exit',()=>{if(Date.now()-began>30000)retry=500;setTimeout(start,retry);retry=Math.min(30000,retry*2);});
 child.on('error',()=>{process.stderr.write('Router child could not start.\n');});
}
start();
