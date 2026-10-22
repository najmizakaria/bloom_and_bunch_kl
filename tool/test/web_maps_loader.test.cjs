'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {readFileSync}=require('node:fs');
const {resolve}=require('node:path');
const vm=require('node:vm');
const source=readFileSync(resolve(__dirname,'../../web/index.html'),'utf8').match(/<script>([\s\S]*?)<\/script>/)[1];
function browser(){
  const scripts=[],timers=new Map(),events=[];
  const window={dispatchEvent:event=>events.push(event.type)};
  const context={window,Event:class {constructor(type){this.type=type;}},Promise,Error,encodeURIComponent,
    setTimeout:fn=>{const id=timers.size+1;timers.set(id,fn);return id;},clearTimeout:id=>timers.delete(id),
    document:{createElement:()=>({remove(){this.removed=true;}}),head:{appendChild:script=>scripts.push(script)}},
  };
  vm.runInNewContext(source,context);
  return {window,scripts,timers,events};
}
test('debug web runs require a supplied key and never request the template placeholder',async()=>{
  const b=browser();await assert.rejects(b.window.bloomLoadMaps(),/configuration missing/);
  assert.equal(b.scripts.length,0);
  const pending=b.window.bloomLoadMaps('test-public-key');
  assert.equal(new URL(b.scripts[0].src).searchParams.get('key'),'test-public-key');
  b.window.google={maps:{Map:class {}}};b.window.bloomMapsLoaded();await pending;
});
test('parallel callers wait for one SDK callback, including a partially loaded namespace',async()=>{
  const b=browser(),first=b.window.bloomLoadMaps('test-key');
  b.window.google={maps:{}};
  const second=b.window.bloomLoadMaps('test-key');assert.equal(first,second);assert.equal(b.scripts.length,1);
  b.window.google.maps.Map=class {};b.window.bloomMapsLoaded();await Promise.all([first,second]);
  assert.equal(b.timers.size,0);
});
test('an authorization failure after SDK readiness notifies Flutter and prevents false readiness',async()=>{
  const b=browser(),ready=b.window.bloomLoadMaps('test-key');
  b.window.google={maps:{Map:class {}}};b.window.bloomMapsLoaded();await ready;
  b.window.gm_authFailure();assert.deepEqual(b.events,['bloom-maps-error']);
  await assert.rejects(b.window.bloomLoadMaps('test-key'),/authorization failed/);
});
test('network failures remove the failed script and allow a new request',async()=>{
  const b=browser(),first=b.window.bloomLoadMaps('test-key');b.scripts[0].onerror();
  await assert.rejects(first,/could not load/);assert.equal(b.scripts[0].removed,true);
  const retry=b.window.bloomLoadMaps('test-key');assert.equal(b.scripts.length,2);
  b.window.google={maps:{Map:class {}}};b.window.bloomMapsLoaded();await retry;
});
test('a callback without a usable Map constructor fails instead of rendering a blank platform view',async()=>{
  const b=browser(),ready=b.window.bloomLoadMaps('test-key');b.window.google={maps:{}};b.window.bloomMapsLoaded();
  await assert.rejects(ready,/could not load/);
});
test('SDK requests time out instead of leaving an indefinite loading screen',async()=>{
  const b=browser(),ready=b.window.bloomLoadMaps('test-key');b.timers.values().next().value();
  await assert.rejects(ready,/could not load/);assert.equal(b.window.bloomMapsPromise,null);
});
