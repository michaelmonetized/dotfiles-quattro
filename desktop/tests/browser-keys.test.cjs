const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
let handler, updated;
const tabs = [{id:8,index:3,active:false},{id:4,index:1,active:true},{id:6,index:2,hidden:true},{id:1,index:0}];
const context = {chrome:{
 windows:{getLastFocused:async()=>({id:1,focused:true})},
 tabs:{query:async()=>tabs,update:async(id,change)=>{updated={id,change}}},
 runtime:{connectNative:()=>({postMessage:()=>{},onMessage:{addListener:f=>handler=f},onDisconnect:{addListener:()=>{}}})}
},console,setTimeout};
vm.createContext(context);vm.runInContext(fs.readFileSync('browser-keys/background.js','utf8'),context);
(async()=>{
 await vm.runInContext("act('next-tab')",context);assert.equal(updated.id,8,'skips hidden tabs, uses index not array/MRU order');
 await vm.runInContext("act('previous-tab')",context);assert.equal(updated.id,1);
 tabs[1].active=false;tabs[2].hidden=false;tabs[0].active=true;
 await vm.runInContext("act('next-tab')",context);assert.equal(updated.id,1,'wraps at end');
 context.chrome.windows.getLastFocused=async()=>({id:1,focused:false});
 await assert.rejects(vm.runInContext("act('close-tab')",context),/not focused/);
 console.log('Visible order, hidden tabs, wraparound and focus guard passed');
})();
