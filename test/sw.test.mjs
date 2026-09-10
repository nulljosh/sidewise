import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import fs from 'node:fs';

test('service worker refreshes API payloads and uses exact cached queries offline', async () => {
  const handlers = {}, cached = new Map();
  let offline = false, version = 0;
  vm.runInNewContext(fs.readFileSync(new URL('../public/sw.js', import.meta.url), 'utf8'), {
    URL, Response, location:{origin:'https://sidewise.test'},
    self:{addEventListener:(name, fn)=>handlers[name]=fn},
    caches:{open:async()=>({put:async(req,res)=>cached.set(req.url,res.clone())}),match:async req=>cached.get(req.url)?.clone()},
    fetch:async()=>{if(offline)throw Error('offline');return new Response(String(++version));}
  });
  async function request(query='') {
    let result;const pending=[];
    handlers.fetch({request:new Request('https://sidewise.test/api/stories'+query),respondWith:p=>result=p,waitUntil:p=>pending.push(p)});
    const response=await result;await Promise.all(pending);return response;
  }
  assert.equal(await (await request()).text(),'1');
  assert.equal(await (await request()).text(),'2');
  offline=true;
  assert.equal(await (await request()).text(),'2');
  assert.equal((await request('?q=different')).type,'error');
});
