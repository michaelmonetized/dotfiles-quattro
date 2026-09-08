const api = globalThis.browser || chrome;
const flavor = api.runtime.getManifest().browser_specific_settings?.gecko ? 'zen' : 'chrome';
async function act(action) {
  const win = await api.windows.getLastFocused();
  if (!win.focused) throw new Error('Browser window is not focused');
  const tabs = (await api.tabs.query({windowId:win.id})).filter(t => !t.hidden).sort((a,b)=>a.index-b.index);
  const tab = tabs.find(t=>t.active);
  if (!tab) throw new Error('No active tab');
  const index = tabs.indexOf(tab);
  if (action === 'next-tab' || action === 'previous-tab') {
    const offset = action === 'next-tab' ? 1 : -1;
    await api.tabs.update(tabs[(index+offset+tabs.length)%tabs.length].id,{active:true});
  } else if (/^tab-[1-9]$/.test(action)) {
    const n = Number(action.slice(4));
    const target = n === 9 ? tabs.at(-1) : tabs[n-1];
    if (target) await api.tabs.update(target.id,{active:true});
  } else if (action === 'new-tab') await api.tabs.create({windowId:win.id});
  else if (action === 'close-tab') await api.tabs.remove(tab.id);
  else if (action === 'restore-tab') await api.sessions.restore();
  else if (action === 'duplicate-tab') await api.tabs.duplicate(tab.id);
  else if (action === 'pin-tab') await api.tabs.update(tab.id,{pinned:!tab.pinned});
  else if (action === 'mute-tab') await api.tabs.update(tab.id,{muted:!tab.mutedInfo.muted});
  else if (action === 'reload') await api.tabs.reload(tab.id);
  else if (action === 'reload-no-cache') await api.tabs.reload(tab.id,{bypassCache:true});
  else if (action === 'back') await api.tabs.goBack(tab.id);
  else if (action === 'forward') await api.tabs.goForward(tab.id);
  else if (action === 'new-window') await api.windows.create({});
  else if (action === 'private-window') await api.windows.create({incognito:true});
  else if (action === 'close-window') await api.windows.remove(win.id);
  else if (action === 'history') await api.tabs.create({url:flavor==='zen'?'about:history':'chrome://history'});
  else if (action === 'downloads') await api.tabs.create({url:flavor==='zen'?'about:downloads':'chrome://downloads'});
  else if (action === 'zoom-in') await api.tabs.setZoom(tab.id,Math.min(5,(await api.tabs.getZoom(tab.id))+.1));
  else if (action === 'zoom-out') await api.tabs.setZoom(tab.id,Math.max(.25,(await api.tabs.getZoom(tab.id))-.1));
  else if (action === 'zoom-reset') await api.tabs.setZoom(tab.id,1);
  else if (action === 'copy-url' || action === 'copy-url-markdown') return {clipboard:action==='copy-url'?tab.url:`[${tab.title}](${tab.url})`};
  else throw new Error('Unknown action: '+action);
  return {};
}
function connect() {
  const port = api.runtime.connectNative('com.michael.browser_keys');
  port.postMessage({browser:flavor});
  port.onMessage.addListener(async message => {
    try { port.postMessage({id:message.id,ok:true,...await act(message.action)}); }
    catch(error) { port.postMessage({id:message.id,ok:false,error:String(error)}); }
  });
  port.onDisconnect.addListener(()=>{ console.warn('Browser Keys disconnected',api.runtime.lastError); setTimeout(connect,3000); });
}
connect();
