import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createReadStream, mkdirSync, mkdtempSync, readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { stripVTControlCharacters } from 'node:util';
import { chromium } from 'playwright';
import { PNG } from 'pngjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const outputRoot = path.join(root, '_build/visual-diff');
mkdirSync(outputRoot, { recursive: true });
const output = mkdtempSync(path.join(outputRoot, 'run-'));
const executable = path.join(root, 'node_modules/.bin/vlmkit');
const allowed = ['/compat/visual/', '/compat/interactive/', '/node_modules/@bdfkit/', '/_build/js/debug/build/browser/'];
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.bdf': 'application/octet-stream' };

function run(args) {
  return new Promise((resolve, reject) => {
    const child = spawn(executable, args, { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '', stderr = '';
    child.stdout.setEncoding('utf8').on('data', chunk => { stdout += chunk; });
    child.stderr.setEncoding('utf8').on('data', chunk => { stderr += chunk; });
    child.once('error', reject);
    child.once('close', (code, signal) => {
      // actrun stores output as JSON; raw ANSI escapes corrupt its run record.
      process.stdout.write(stripVTControlCharacters(stdout));
      process.stderr.write(stripVTControlCharacters(stderr));
      code === 0 ? resolve() : reject(new Error(`vlmkit failed: ${signal ?? code}`));
    });
  });
}

const server = createServer((request, response) => {
  let pathname;
  try { pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname); }
  catch { response.writeHead(400).end(); return; }
  const file = path.resolve(root, '.' + pathname);
  if (!allowed.some(prefix => file.startsWith(path.resolve(root, '.' + prefix) + path.sep))) {
    response.writeHead(403).end(); return;
  }
  const stream = createReadStream(file);
  stream.once('error', () => { if (!response.headersSent) response.writeHead(404); response.end(); });
  response.setHeader('Content-Type', mime[path.extname(file)] ?? 'application/octet-stream');
  stream.pipe(response);
});

await new Promise((resolve, reject) => {
  server.once('error', reject);
  server.listen(0, '127.0.0.1', resolve);
});
const base = `http://127.0.0.1:${server.address().port}/compat/visual/`;
try {
  // A visual diff is not evidence if both pages failed or were still blank.
  const browser = await chromium.launch({ headless: true });
  try {
    for (const name of ['baseline', 'moon', 'split', 'encrypted-password', 'encrypted-split', 'encrypted-ecdh', 'encrypted-ecdh-split']) {
      const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
      const errors = [];
      page.on('pageerror', error => errors.push(String(error)));
      await page.goto(`${base}${name}.html`, { waitUntil: 'networkidle' });
      await page.waitForFunction(() => window.bdfStatus === 'ready' || window.bdfStatus === 'error');
      const result = await page.evaluate(() => ({ status: window.bdfStatus, error: window.bdfError, canvases: document.querySelectorAll('canvas').length }));
      assert.equal(result.status, 'ready', `${name}: ${result.error ?? errors.join('; ')}`);
      assert.equal(result.canvases, 1, `${name}: expected a rendered canvas`);
      assert.deepEqual(errors, [], `${name}: browser errors`);
      if (name === 'split') {
        const failures = await page.evaluate(async () => {
          const { mount_bdf_split_async } = await import('/_build/js/debug/build/browser/browser.js');
          const manifest = new Uint8Array(await (await fetch('./split-fixture/manifest.json')).arrayBuffer());
          const attempts = [
            async (_hash, limit) => new Uint8Array(limit + 1),
            async (_hash, limit) => new Uint8Array(limit - 1),
            async () => { throw new Error('loader failed'); },
            async () => 'not bytes',
          ];
          return Promise.all(attempts.map(async loader => {
            const host = document.createElement('div');
            host.textContent = 'unchanged';
            try { await mount_bdf_split_async(host, manifest, loader, 'single'); return false; }
            catch { return host.textContent === 'unchanged' && host.childElementCount === 0; }
          }));
        });
        assert.deepEqual(failures, [true, true, true, true], 'split loader failure handling');
      }
      if (name === 'encrypted-password') {
        const failures = await page.evaluate(async () => {
          const { mount_bdf_encrypted_async, mount_bdf_encrypted_split_async } = await import('/_build/js/debug/build/browser/browser.js');
          const dir = './encrypted-fixture/';
          const bytes = async file => new Uint8Array(await (await fetch(`${dir}${file}`)).arrayBuffer());
          const single = await bytes('password.bdf');
          const manifestBytes = await bytes('password-split/manifest.json');
          const metadata = JSON.parse(new TextDecoder().decode(manifestBytes));
          const manifestHash = metadata.encryption.manifest.part;
          const firstPart = metadata.parts.find(part => part.h !== manifestHash).h;
          const loader = async hash => bytes(`password-split/parts/${hash}`);
          const corrupt = hashToCorrupt => async hash => {
            const part = await loader(hash);
            if (hash === hashToCorrupt) part[15] ^= 1;
            return part;
          };
          const tamperedSingle = single.slice();
          const view = new DataView(tamperedSingle.buffer);
          const start = Number(view.getBigUint64(8, true) + view.getBigUint64(16, true));
          tamperedSingle[start + 15] ^= 1;
          const hostile = structuredClone(metadata);
          hostile.encryption.keys[0].iter = 10000001;
          let loaded = false;
          const hostileLoader = async hash => { loaded = true; return loader(hash); };
          const wrongPair = await crypto.subtle.generateKey({name:'ECDH', namedCurve:'P-256'}, true, ['deriveKey']);
          const ecdh = await bytes('ecdh.bdf');
          const cases = [
            host => mount_bdf_encrypted_async(host, single, 'wrong', 'single'),
            host => mount_bdf_encrypted_async(host, tamperedSingle, 'pass', 'single'),
            host => mount_bdf_encrypted_async(host, ecdh, wrongPair, 'single'),
            host => mount_bdf_encrypted_split_async(host, manifestBytes, corrupt(manifestHash), 'pass', 'single'),
            host => mount_bdf_encrypted_split_async(host, manifestBytes, corrupt(firstPart), 'pass', 'single'),
            host => mount_bdf_encrypted_split_async(host, new TextEncoder().encode(JSON.stringify(hostile)), hostileLoader, 'pass', 'single'),
          ];
          const results = [];
          for (const test of cases) {
            const host = document.createElement('div'); host.textContent = 'unchanged';
            try { await test(host); results.push(false); }
            catch { results.push(host.textContent === 'unchanged' && host.childElementCount === 0); }
          }
          return { results, loaded };
        });
        assert.deepEqual(failures.results, [true, true, true, true, true, true], 'encrypted failure handling');
        assert.equal(failures.loaded, false, 'invalid key slot fetched data');
      }
      await page.close();
    }
    const interactiveBase = `http://127.0.0.1:${server.address().port}/compat/interactive/`;
    const snapshots = [];
    for (const name of ['baseline', 'moon']) {
      const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
      const errors = [];
      page.on('pageerror', error => errors.push(String(error)));
      await page.goto(`${interactiveBase}${name}.html`, {waitUntil:'networkidle'});
      await page.waitForFunction(() => window.bdfStatus === 'ready' || window.bdfStatus === 'error');
      const snapshot = await page.evaluate(() => {
        if (window.bdfStatus !== 'ready') throw new Error(window.bdfError);
        const host=document.querySelector('#host'), spans=[...host.querySelectorAll('[data-bdf-ordinal]')];
        const roles=[...host.querySelectorAll('[role]')].map(el=>({role:el.getAttribute('role'),level:el.getAttribute('aria-level'),row:el.getAttribute('aria-rowindex'),col:el.getAttribute('aria-colindex'),colspan:el.getAttribute('aria-colspan'),label:el.getAttribute('aria-label')}));
        const anchors=[...host.querySelectorAll('a')].map(a=>({href:a.getAttribute('href'),page:a.getAttribute('data-bdf-page'),text:a.textContent}));
        const geometry=spans.map(span=>{const r=span.getBoundingClientRect();return [r.x,r.y,r.width,r.height]});
        const range=document.createRange();range.setStart(spans[1].firstChild,1);range.setEnd(spans[3].firstChild,6);
        const selection=getSelection();selection.removeAllRanges();selection.addRange(range);
        const selected=window.readSelection();const multiRange=document.createRange();multiRange.setStart(spans[1].firstChild,1);multiRange.setEnd(spans.at(-1).firstChild,spans.at(-1).textContent.length);selection.removeAllRanges();selection.addRange(multiRange);const crossPage=window.readSelection();selection.removeAllRanges();selection.addRange(range);const clipboard=new DataTransfer();const event=new ClipboardEvent('copy',{bubbles:true,cancelable:true,clipboardData:clipboard});host.dispatchEvent(event);const cutData=new DataTransfer();const cutEvent=new ClipboardEvent('cut',{bubbles:true,cancelable:true,clipboardData:cutData});host.dispatchEvent(cutEvent);
        const header=spans.find(s=>s.textContent==='Header'), value=spans.find(s=>s.textContent==='42');
        const cellRange=document.createRange();cellRange.setStart(header.firstChild,1);cellRange.setEnd(value.firstChild,1);selection.removeAllRanges();selection.addRange(cellRange);document.dispatchEvent(new Event('selectionchange'));
        const box=host.querySelector('[data-bdf-cellbox]'),rect=box?.getBoundingClientRect();
        const tableData=new DataTransfer(),tableCopy=new ClipboardEvent('copy',{bubbles:true,cancelable:true,clipboardData:tableData});host.dispatchEvent(tableCopy);const tableCutData=new DataTransfer(),tableCut=new ClipboardEvent('cut',{bubbles:true,cancelable:true,clipboardData:tableCutData});host.dispatchEvent(tableCut);
        const cellResult={active:!!host.querySelector('[role=table][data-bdf-cells]'),box:rect?[rect.x,rect.y,rect.width,rect.height]:null,plain:tableData.getData('text/plain'),html:tableData.getData('text/html'),prevented:tableCopy.defaultPrevented,cut:tableCutData.getData('text/plain'),cutHtml:tableCutData.getData('text/html'),cutPrevented:tableCut.defaultPrevented,api:window.readCells()};
        selection.setBaseAndExtent(value.firstChild,1,header.firstChild,1);document.dispatchEvent(new Event('selectionchange'));
        const reverseData=new DataTransfer(),reverseCopy=new ClipboardEvent('copy',{bubbles:true,cancelable:true,clipboardData:reverseData});host.dispatchEvent(reverseCopy);
        const reverseCell={active:!!host.querySelector('[data-bdf-cellbox]'),plain:reverseData.getData('text/plain'),html:reverseData.getData('text/html')};
        const outsideRange=document.createRange();outsideRange.setStart(header.firstChild,0);outsideRange.setEnd(spans.at(-1).firstChild,3);selection.removeAllRanges();selection.addRange(outsideRange);document.dispatchEvent(new Event('selectionchange'));
        const outsideData=new DataTransfer(),outsideCopy=new ClipboardEvent('copy',{bubbles:true,cancelable:true,clipboardData:outsideData});host.dispatchEvent(outsideCopy);
        const outsideCell={active:!!host.querySelector('[data-bdf-cellbox]'),plain:outsideData.getData('text/plain'),html:outsideData.getData('text/html')};
        const annoX=spans.find(s=>s.textContent==='Anno X'),annoY=spans.find(s=>s.textContent==='Anno Y');
        const annotationRange=document.createRange();annotationRange.setStart(annoX.firstChild,0);annotationRange.setEnd(annoY.firstChild,annoY.textContent.length);selection.removeAllRanges();selection.addRange(annotationRange);document.dispatchEvent(new Event('selectionchange'));
        const annotationData=new DataTransfer(),annotationCopy=new ClipboardEvent('copy',{bubbles:true,cancelable:true,clipboardData:annotationData});host.dispatchEvent(annotationCopy);
        const annotationCells={active:!!host.querySelector('[data-bdf-cellbox]'),plain:annotationData.getData('text/plain'),html:annotationData.getData('text/html')};
        const differentTables=document.createRange();differentTables.setStart(value.firstChild,0);differentTables.setEnd(annoY.firstChild,2);selection.removeAllRanges();selection.addRange(differentTables);document.dispatchEvent(new Event('selectionchange'));
        const mixedData=new DataTransfer(),mixedCopy=new ClipboardEvent('copy',{bubbles:true,cancelable:true,clipboardData:mixedData});host.dispatchEvent(mixedCopy);
        const mixedTables={active:!!host.querySelector('[data-bdf-cellbox]'),plain:mixedData.getData('text/plain'),html:mixedData.getData('text/html')};
        const singleCell=document.createRange();singleCell.setStart(header.firstChild,1);singleCell.setEnd(header.firstChild,4);selection.removeAllRanges();selection.addRange(singleCell);document.dispatchEvent(new Event('selectionchange'));
        const singleData=new DataTransfer(),singleCopy=new ClipboardEvent('copy',{bubbles:true,cancelable:true,clipboardData:singleData});host.dispatchEvent(singleCopy);
        const singleCellResult={active:!!host.querySelector('[data-bdf-cellbox]'),plain:singleData.getData('text/plain'),html:singleData.getData('text/html'),noCells:window.readCells()==null};
        const farLeft=spans.find(s=>s.textContent==='Far left'),farRight=spans.find(s=>s.textContent==='Far right');
        const huge=document.createRange();huge.setStart(farLeft.firstChild,0);huge.setEnd(farRight.firstChild,farRight.textContent.length);selection.removeAllRanges();selection.addRange(huge);document.dispatchEvent(new Event('selectionchange'));
        let hugeRejected=false;try{window.readCells()}catch{hugeRejected=true}
        const hugeData=new DataTransfer(),hugeCopy=new ClipboardEvent('copy',{bubbles:true,cancelable:true,clipboardData:hugeData});host.dispatchEvent(hugeCopy);
        const hugeResult={rejected:hugeRejected,plain:hugeData.getData('text/plain'),html:hugeData.getData('text/html'),prevented:hugeCopy.defaultPrevented};
        return {texts:spans.map(s=>s.textContent),seps:spans.map(s=>s.getAttribute('data-bdf-sep')),ordinals:spans.map(s=>s.getAttribute('data-bdf-ordinal')),roles,anchors,geometry,selected,crossPage,copied:clipboard.getData('text/plain'),prevented:event.defaultPrevented,cut:cutData.getData('text/plain'),cutPrevented:cutEvent.defaultPrevented,cellResult,reverseCell,outsideCell,singleCellResult,hugeResult,annotationCells,mixedTables};
      });
      assert.deepEqual(errors, [], `${name}: browser errors`);
      assert.equal(snapshot.selected, 'ello world Second');
      assert.ok(snapshot.crossPage.endsWith('\n\nSecond page'), 'cross-page selection separator');
      assert.equal(snapshot.copied, snapshot.selected);
      assert.equal(snapshot.prevented, true);
      assert.equal(snapshot.cut, snapshot.selected);
      assert.equal(snapshot.cutPrevented, true);
      assert.equal(snapshot.cellResult.active,true);
      assert.equal(snapshot.cellResult.plain,'Header\tValue\t\nPrice\t42\t');
      assert.equal(snapshot.cellResult.prevented,true);
      assert.equal(snapshot.cellResult.cut,snapshot.cellResult.plain);
      assert.equal(snapshot.cellResult.cutHtml,snapshot.cellResult.html);
      assert.equal(snapshot.cellResult.cutPrevented,true);
      assert.deepEqual(snapshot.reverseCell,{active:true,plain:snapshot.cellResult.plain,html:snapshot.cellResult.html});
      assert.equal(snapshot.outsideCell.active,false);
      assert.equal(snapshot.outsideCell.html,'');
      assert.ok(snapshot.outsideCell.plain.endsWith('\n\nSec'));
      assert.deepEqual(snapshot.singleCellResult,{active:false,plain:'ead',html:'',noCells:true});
      assert.deepEqual(snapshot.cellResult.api,{text:snapshot.cellResult.plain,html:snapshot.cellResult.html});
      assert.deepEqual(snapshot.hugeResult,{rejected:true,plain:'Far left\nFar right',html:'',prevented:true});
      assert.equal(snapshot.annotationCells.active,true);
      assert.equal(snapshot.annotationCells.plain,'Anno X\tAnno Y');
      assert.equal(snapshot.mixedTables.active,false);
      assert.equal(snapshot.mixedTables.html,'');
      assert.equal(snapshot.anchors.length, 1, 'unsafe link must not be rendered');
      assert.equal(snapshot.anchors[0].page, '1');
      await page.evaluate(() => getSelection().removeAllRanges());
      const [tx,ty,tw,th] = snapshot.geometry[1];
      await page.mouse.move(tx+2,ty+th/2);
      await page.mouse.down();
      const tracking = await page.evaluate(() => ({
        active: document.querySelector('[data-bdf-layer]')?.hasAttribute('data-bdf-selecting'),
        cover: !!document.querySelector('[data-bdf-end][data-bdf-selecting]'),
      }));
      assert.deepEqual(tracking, {active:true,cover:true}, 'drag selection cover activates');
      await page.mouse.move(tx+tw-2,ty+th/2,{steps:8});
      await page.mouse.move(300,115,{steps:8});
      const dragged = await page.evaluate(() => window.readSelection());
      assert.ok(dragged.length > 0, 'drag retains selected text');
      await page.mouse.up();
      assert.equal(await page.evaluate(() => !!document.querySelector('[data-bdf-end][data-bdf-selecting]')), false, 'drag cover clears on release');
      snapshot.dragged=dragged;
      await page.evaluate(() => getSelection().removeAllRanges());
      const [bx,by,bw,bh] = snapshot.geometry[2];
      await page.mouse.move(bx+bw-2,by+bh/2);
      await page.mouse.down();
      await page.mouse.move(tx+2,ty+th/2,{steps:10});
      snapshot.draggedBack=await page.evaluate(() => window.readSelection());
      assert.ok(snapshot.draggedBack.length > 0, 'backward drag selects text');
      await page.mouse.up();
      assert.equal(await page.evaluate(() => !!document.querySelector('[data-bdf-end][data-bdf-selecting]')), false);
      await page.evaluate(() => getSelection().removeAllRanges());
      const outsideTracking = await page.evaluate(() => {
        const spans=[...document.querySelectorAll('[data-bdf-ordinal]')];
        document.body.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true,button:0,pointerType:'mouse'}));
        const range=document.createRange();range.setStart(spans[1].firstChild,0);range.setEnd(spans[2].firstChild,3);
        getSelection().removeAllRanges();getSelection().addRange(range);
        document.dispatchEvent(new Event('selectionchange'));
        const active=!!document.querySelector('[data-bdf-end][data-bdf-selecting]');
        document.dispatchEvent(new PointerEvent('pointerup',{bubbles:true,pointerType:'mouse'}));
        return active;
      });
      assert.equal(outsideTracking,true,'drag beginning outside host is tracked');
      await page.evaluate(() => getSelection().removeAllRanges());
      await page.keyboard.press('Tab');
      assert.equal(await page.evaluate(() => document.activeElement?.getAttribute('data-bdf-page')), '1');
      await page.keyboard.press('Enter');
      assert.equal(await page.evaluate(() => location.hash), '#page=1');
      snapshots.push(snapshot);
      await page.close();
    }
    for (const name of ['selected-baseline','selected-moon']) {
      const page=await browser.newPage({viewport:{width:1280,height:720}});
      await page.goto(`${interactiveBase}${name}.html`,{waitUntil:'networkidle'});
      await page.waitForFunction(() => window.bdfStatus==='ready'||window.bdfStatus==='error');
      assert.equal(await page.evaluate(() => window.bdfStatus),'ready',`${name}: selected fixture failed`);
      const selection=await page.evaluate(() => ({box:!!document.querySelector('[data-bdf-cellbox]'),table:!!document.querySelector('[role=table][data-bdf-cells]')}));
      assert.deepEqual(selection,{box:true,table:true},`${name}: selected cell highlight missing`);
      await page.close();
    }
    const findSnapshots=[];
    for (const name of ['find-baseline','find-moon']) {
      const page=await browser.newPage({viewport:{width:1280,height:720}}),errors=[];
      page.on('pageerror',error=>errors.push(String(error)));
      await page.goto(`${interactiveBase}${name}.html`,{waitUntil:'networkidle'});
      await page.waitForFunction(()=>window.bdfStatus==='ready'||window.bdfStatus==='error');
      assert.equal(await page.evaluate(()=>window.bdfStatus),'ready',`${name}: ${await page.evaluate(()=>window.bdfError)}`);
      const actual=await page.evaluate(async()=>{
        const result=[],events=[],host=document.querySelector('#host');
        const onfind=event=>events.push(event.detail);host.addEventListener('findchange',onfind);
        for(const [q,step] of [['page',0],['page',1],['page',-1],['absent',0],['',0],['hello world',0]]){
          const r=await window.findAction(q,step);result.push({query:r.query,index:r.index,total:r.total,more:r.more,detail:r.detail,rects:r.rects.map(({hit,page,x,y,w,h})=>({hit,page,x,y,w,h}))});
        }
        host.removeEventListener('findchange',onfind);
        return {result,events};
      });
      findSnapshots.push(actual);
      const input=page.getByRole('searchbox',{name:'Find in document'});
      const apple=await page.evaluate(()=>/mac|iphone|ipad|ipod/i.test(navigator.userAgentData?.platform||navigator.platform||navigator.userAgent||''));
      await page.getByRole('button',{name:'Previous match'}).focus();
      await page.keyboard.press('Shift+Tab');
      const keyboardFocus=await input.evaluate(el=>({focused:document.activeElement===el,outline:getComputedStyle(el).outlineStyle}));
      assert.equal(keyboardFocus.focused,true,`${name}: search field is not keyboard reachable`);
      assert.notEqual(keyboardFocus.outline,'none',`${name}: search field has no keyboard focus indicator`);
      await input.fill('page');await page.waitForFunction(()=>document.querySelector('[role=status]')?.textContent.startsWith('1 / 2'));
      await input.press('Enter');await page.waitForFunction(()=>document.querySelector('[role=status]')?.textContent.startsWith('2 / 2'));
      await input.press('Shift+Enter');await page.waitForFunction(()=>document.querySelector('[role=status]')?.textContent.startsWith('1 / 2'));
      await page.getByRole('button',{name:'Next match'}).click();await page.waitForFunction(()=>document.querySelector('[role=status]')?.textContent.startsWith('2 / 2'));
      await page.getByRole('button',{name:'Previous match'}).click();await page.waitForFunction(()=>document.querySelector('[role=status]')?.textContent.startsWith('1 / 2'));
      await page.keyboard.press('F3');await page.waitForFunction(()=>document.querySelector('[role=status]')?.textContent.startsWith('2 / 2'));
      await input.press(apple?'Meta+g':'Control+g');await page.waitForFunction(()=>document.querySelector('[role=status]')?.textContent.startsWith('1 / 2'));
      await input.press(apple?'Meta+Shift+g':'Control+Shift+g');await page.waitForFunction(()=>document.querySelector('[role=status]')?.textContent.startsWith('2 / 2'));
      const browserShortcut=await input.evaluate((el,apple)=>el.dispatchEvent(new KeyboardEvent('keydown',{key:'f',code:'KeyF',ctrlKey:!apple,metaKey:apple,bubbles:true,cancelable:true})),apple);
      assert.equal(browserShortcut,true,`${name}: browser find was intercepted inside the search field`);
      await input.evaluate(el=>{el.value='missing';el.dispatchEvent(new InputEvent('input',{bubbles:true,isComposing:true}));});
      await page.waitForTimeout(200);
      assert.match(await page.getByRole('status').innerText(),/^2 \/ 2/,`${name}: searched during composition`);
      await input.evaluate(el=>el.dispatchEvent(new CompositionEvent('compositionend',{bubbles:true})));
      await page.waitForFunction(()=>document.querySelector('[role=status]')?.textContent==='No matches');
      await input.press('Escape');assert.equal(await page.getByRole('search').count(),0,`${name}: search bar remained visible`);
      assert.equal(await page.evaluate(()=>document.activeElement?.id),'host',`${name}: closing search lost viewer focus`);
      await page.keyboard.press(apple?'Meta+f':'Control+f');assert.equal(await page.getByRole('search').count(),1,`${name}: shortcut did not reopen search`);
      assert.equal(await input.inputValue(),'missing',`${name}: reopening lost query`);
      await page.getByRole('button',{name:'Close'}).click();assert.equal(await page.getByRole('search').count(),0,`${name}: close button did not hide search`);
      assert.equal(await page.evaluate(()=>document.activeElement?.id),'host',`${name}: close button lost viewer focus`);
      assert.deepEqual(errors,[],`${name}: browser errors`);
      await page.close();
    }
    assert.deepEqual(findSnapshots[1],findSnapshots[0],'find results, locations and navigation match upstream');
    const resourcePage = await browser.newPage();
    await resourcePage.goto(`${interactiveBase}moon.html`, {waitUntil:'networkidle'});
    await resourcePage.waitForFunction(() => window.bdfStatus === 'ready');
    const resourceResult = await resourcePage.evaluate(async () => {
      const bdf = await import('/_build/js/debug/build/browser/browser.js');
      const visual = '../visual/';
      const bytes = async path => new Uint8Array(await (await fetch(`${visual}${path}`)).arrayBuffer());
      const partLoader = prefix => async (hash, maximum) => {
        const part = await bytes(`${prefix}/parts/${hash}`);
        if (part.length > maximum) throw new Error('part exceeds limit');
        return part;
      };
      const jwk = await (await fetch(`${visual}encrypted-fixture/test-private.jwk`)).json();
      const privateKey = await crypto.subtle.importKey('jwk',jwk,{name:'ECDH',namedCurve:'P-256'},false,['deriveKey']);
      const {d,...pub} = jwk;
      const publicKey = await crypto.subtle.importKey('jwk',pub,{name:'ECDH',namedCurve:'P-256'},true,[]);
      const pair = {publicKey,privateKey};
      const cases = [
        host => bytes('fixture.bdf').then(data=>bdf.mount_bdf_interactive_async(host,data,'single')),
        host => bytes('split-fixture/manifest.json').then(manifest=>bdf.mount_bdf_interactive_split_async(host,manifest,partLoader('split-fixture'),'single')),
        host => bytes('encrypted-fixture/password.bdf').then(data=>bdf.mount_bdf_interactive_encrypted_async(host,data,'pass','single')),
        host => bytes('encrypted-fixture/password-split/manifest.json').then(manifest=>bdf.mount_bdf_interactive_encrypted_split_async(host,manifest,partLoader('encrypted-fixture/password-split'),'pass','single')),
        host => bytes('encrypted-fixture/ecdh.bdf').then(data=>bdf.mount_bdf_interactive_encrypted_async(host,data,pair,'single')),
        host => bytes('encrypted-fixture/ecdh-split/manifest.json').then(manifest=>bdf.mount_bdf_interactive_encrypted_split_async(host,manifest,partLoader('encrypted-fixture/ecdh-split'),pair,'single')),
      ];
      const initial=[...document.fonts].filter(f=>f.family.startsWith('bdf-')).length;
      const results=[];
      for (const [i, mount] of cases.entries()) {
        const host=document.createElement('div');document.body.appendChild(host);
        const pages=await mount(host);
        const spans=[...host.querySelectorAll('[data-bdf-ordinal]')];
        const texts=spans.map(s=>s.textContent);
        const syntheticWidth=spans.find(s=>s.textContent==='AAA').getBoundingClientRect().width;
        const retained=[...document.fonts].filter(f=>f.family.startsWith('bdf-')).length;
        const found=bdf.bdf_find(host,'AAA',0);
        if (i%2===0) { bdf.unmount_bdf(host); host.remove(); }
        else { host.remove(); await new Promise(resolve=>setTimeout(resolve,0)); }
        const released=[...document.fonts].filter(f=>f.family.startsWith('bdf-')).length;
        const handlersReleased=!host[Symbol.for('f4ah6o.bdf.copy')]&&!host[Symbol.for('f4ah6o.bdf.find')];
        results.push({pages,texts,syntheticWidth,retained,released,handlersReleased,found:found.total,empty:host.childElementCount===0,resetSize:host.style.minWidth===''&&host.style.minHeight===''});
      }
      const detached=document.createElement('div');
      await bdf.mount_bdf_interactive_async(detached,await bytes('fixture.bdf'),'single');
      document.body.appendChild(detached);
      await new Promise(resolve=>setTimeout(resolve,0));
      const detachedSpans=detached.querySelectorAll('[data-bdf-ordinal]');
      document.body.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true,button:0,pointerType:'mouse'}));
      const range=document.createRange();range.setStart(detachedSpans[0].firstChild,0);range.setEnd(detachedSpans[0].firstChild,3);
      getSelection().removeAllRanges();getSelection().addRange(range);document.dispatchEvent(new Event('selectionchange'));
      const detachedTracking=!!detached.querySelector('[data-bdf-end][data-bdf-selecting]');
      document.dispatchEvent(new PointerEvent('pointerup',{bubbles:true,pointerType:'mouse'}));
      detached.remove();await new Promise(resolve=>setTimeout(resolve,0));
      const detachedReleased=!detached[Symbol.for('f4ah6o.bdf.copy')]&&!detached[Symbol.for('f4ah6o.bdf.find')]&&[...document.fonts].filter(f=>f.family.startsWith('bdf-')).length===initial;
      const first=document.createElement('div'),second=document.createElement('div');
      document.body.append(first,second);
      const single=await bytes('fixture.bdf');
      await bdf.mount_bdf_interactive_async(first,single,'single');
      await bdf.mount_bdf_interactive_async(second,single,'single');
      const isolated=bdf.bdf_find(first,'AAA',0).total===1&&bdf.bdf_find(second,'absent',0).total===0;
      let failedMount=false;
      try { await bdf.mount_bdf_interactive_split_async(first,await bytes('split-fixture/manifest.json'),async()=>{throw new Error('failed')},'single'); }
      catch { failedMount=first.querySelectorAll('[data-bdf-ordinal]').length===2&&[...document.fonts].filter(f=>f.family.startsWith('bdf-')).length===initial+2; }
      first.remove();await new Promise(resolve=>setTimeout(resolve,0));
      const retainedOther=[...document.fonts].filter(f=>f.family.startsWith('bdf-')).length===initial+1;
      const otherSpan=second.querySelector('[data-bdf-ordinal]');
      document.body.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true,button:0,pointerType:'mouse'}));
      const otherRange=document.createRange();otherRange.setStart(otherSpan.firstChild,0);otherRange.setEnd(otherSpan.firstChild,3);
      getSelection().removeAllRanges();getSelection().addRange(otherRange);document.dispatchEvent(new Event('selectionchange'));
      const otherTracking=!!second.querySelector('[data-bdf-end][data-bdf-selecting]');
      document.dispatchEvent(new PointerEvent('pointerup',{bubbles:true,pointerType:'mouse'}));
      bdf.unmount_bdf(second);second.remove();
      const otherReleased=[...document.fonts].filter(f=>f.family.startsWith('bdf-')).length===initial;
      const indexed=await (await fetch('./indexed.bdf')).arrayBuffer();
      const indexedManifest=await (await fetch('./indexed-split/manifest.json')).arrayBuffer();
      const metadata=JSON.parse(new TextDecoder().decode(indexedManifest));
      const requests=[];
      const indexedLoader=async(hash,limit)=>{requests.push(hash);const part=new Uint8Array(await (await fetch(`./indexed-split/parts/${hash}`)).arrayBuffer());if(part.length>limit)throw new Error('part exceeds limit');return part};
      const indexedHost=document.createElement('div');document.body.appendChild(indexedHost);
      await bdf.mount_bdf_interactive_async(indexedHost,new Uint8Array(indexed),'single');
      const indexedSingle=bdf.bdf_find(indexedHost,'index only text',0).total;
      const indexedDoesNotRebuild=bdf.bdf_find(indexedHost,'document example',0).total===0;
      const defaultStep=bdf.bdf_find(indexedHost,'page',0).index===0&&bdf.bdf_find(indexedHost,'page').index===1;
      bdf.bdf_open_find(indexedHost);
      const openedAfterSearch=indexedHost.querySelector('[role=status]').textContent.startsWith('2 / 2');
      await bdf.mount_bdf_interactive_split_async(indexedHost,new Uint8Array(indexedManifest),indexedLoader,'single');
      const indexedSplit=bdf.bdf_find(indexedHost,'index only text',0).total;
      const indexRequests=requests.filter(hash=>hash===metadata.views[0].textIndex).length;
      const failingIndex=async(hash,limit)=>{if(hash===metadata.views[0].textIndex)throw new Error('index unavailable');return indexedLoader(hash,limit)};
      await bdf.mount_bdf_interactive_split_async(indexedHost,new Uint8Array(indexedManifest),failingIndex,'single');
      let deferredFailure=false;
      try{bdf.bdf_find(indexedHost,'world',0)}catch{deferredFailure=indexedHost.querySelectorAll('[data-bdf-ordinal]').length>0}
      bdf.unmount_bdf(indexedHost);indexedHost.remove();
      const scrollHost=document.createElement('div');scrollHost.style.maxHeight='100px';document.body.appendChild(scrollHost);
      await bdf.mount_bdf_interactive_async(scrollHost,new Uint8Array(indexed),'single');
      scrollHost.style.minHeight='0';scrollHost.style.height='100px';scrollHost.style.minWidth='0';scrollHost.style.width='200px';
      scrollHost.scrollTop=416;
      const startsAtReadingPage=bdf.bdf_find(scrollHost,'page',0).index===1;
      bdf.bdf_open_find(scrollHost);scrollHost.scrollLeft=120;scrollHost.dispatchEvent(new Event('scroll'));
      const anchored=Math.abs(scrollHost.querySelector('[role=search]').getBoundingClientRect().top-scrollHost.getBoundingClientRect().top-8)<1;
      const anchoredHorizontal=Math.abs(scrollHost.getBoundingClientRect().right-scrollHost.querySelector('[role=search]').getBoundingClientRect().right-24)<1;
      bdf.unmount_bdf(scrollHost);scrollHost.remove();
      return {initial,results,detachedTracking,detachedReleased,retainedOther,otherTracking,otherReleased,failedMount,isolated,indexedSingle,indexedSplit,indexRequests,deferredFailure,indexedDoesNotRebuild,defaultStep,startsAtReadingPage,anchored,anchoredHorizontal,openedAfterSearch};
    });
    assert.equal(resourceResult.failedMount,true,'failed preparation preserves existing document and fonts');
    assert.equal(resourceResult.isolated,true,'search is isolated by host');
    assert.deepEqual([resourceResult.indexedSingle,resourceResult.indexedSplit,resourceResult.indexRequests],[1,1,1],'stored text index is loaded for single and split documents');
    assert.equal(resourceResult.deferredFailure,true,'an unavailable index fails search without preventing rendering');
    assert.equal(resourceResult.indexedDoesNotRebuild,true,'stored index takes precedence over extracted text');
    assert.equal(resourceResult.defaultStep,true,'omitted search step advances to the next match');
    assert.equal(resourceResult.openedAfterSearch,true,'opening the bar displays an existing programmatic search');
    assert.equal(resourceResult.startsAtReadingPage,true,'new searches start at the page being read');
    assert.equal(resourceResult.anchored,true,'search bar remains at the top of the scrollport');
    assert.equal(resourceResult.anchoredHorizontal,true,'search bar remains at the right edge during horizontal scrolling');
    assert.equal(resourceResult.retainedOther,true,'removing one host preserves another host font');
    assert.equal(resourceResult.otherTracking,true,'remaining host tracks selection');
    assert.equal(resourceResult.otherReleased,true,'remaining host font is released');
    assert.equal(resourceResult.detachedTracking,true,'detached host activates after insertion');
    assert.equal(resourceResult.detachedReleased,true,'detached host resources are released after removal');
    for (const [i, result] of resourceResult.results.entries()) {
      assert.equal(result.pages, 1);
      assert.deepEqual(result.texts, ['BDF visual parity', 'AAA']);
      assert.ok(Math.abs(result.syntheticWidth-84) < 1, 'embedded font metrics are used for selectable text');
      assert.equal(result.retained, resourceResult.initial + 1, 'embedded font retained for selectable text');
      assert.equal(result.released, resourceResult.initial, 'embedded font released');
      assert.equal(result.handlersReleased, true, 'selection handlers released');
      assert.equal(result.found,1,'interactive mount searches embedded text');
      if (i % 2 === 0) { assert.equal(result.empty, true, 'unmount clears host'); assert.equal(result.resetSize, true, 'unmount resets host dimensions'); }
    }
    await resourcePage.close();
    const [expected, actual] = snapshots;
    for (const key of ['texts','seps','ordinals','roles','anchors','selected','crossPage','copied','prevented','cut','cutPrevented','dragged','draggedBack','singleCellResult','reverseCell','outsideCell','hugeResult','annotationCells','mixedTables']) assert.deepEqual(actual[key], expected[key], `interactive ${key}`);
    for (const key of ['active','plain','html','prevented','cut','cutHtml','cutPrevented','api']) assert.deepEqual(actual.cellResult[key],expected.cellResult[key], `cell ${key}`);
    for (let i=0;i<4;i++) assert.ok(Math.abs(actual.cellResult.box[i]-expected.cellResult.box[i])<1, `cell box ${i}`);
    for (let i=0;i<expected.geometry.length;i++) for (let j=0;j<4;j++) assert.ok(Math.abs(actual.geometry[i][j]-expected.geometry[i][j]) < 1, `interactive span ${i} geometry ${j}`);
  } finally {
    await browser.close();
  }
  const interactiveBase = `http://127.0.0.1:${server.address().port}/compat/interactive/`;
  const interactiveOutput = path.join(output, 'interactive');
  mkdirSync(interactiveOutput);
  await run(['diff','html','--url',`${interactiveBase}baseline.html`,'--current-url',`${interactiveBase}moon.html`,'--output-dir',interactiveOutput,'--no-paint-tree']);
  const interactiveReportPath = path.join(interactiveOutput, 'diff-report.json');
  const interactiveReport = JSON.parse(readFileSync(interactiveReportPath, 'utf8'));
  for (const result of interactiveReport.results) {
    const before = PNG.sync.read(readFileSync(path.join(interactiveOutput, `compat_interactive_baseline-${result.viewport}.png`)));
    const after = PNG.sync.read(readFileSync(path.join(interactiveOutput, `compat_interactive_moon-${result.viewport}.png`)));
    let changed=0;
    for (let i=0;i<before.data.length;i+=4) if (before.data[i]!==after.data[i]||before.data[i+1]!==after.data[i+1]||before.data[i+2]!==after.data[i+2]||before.data[i+3]!==after.data[i+3]) changed++;
    const ratio=changed/(Math.min(before.width,640)*Math.min(before.height,400));
    console.log(`interactive ${result.viewport}: ${changed} pixels changed (${(ratio*100).toFixed(4)}%)`);
    assert.ok(ratio <= 0.0005, `${result.viewport}: interactive visual difference exceeds 0.05%`);
  }
  await run(['diff','agent',interactiveReportPath,'--no-history']);
  const selectedOutput=path.join(output,'selected-cells');mkdirSync(selectedOutput);
  await run(['diff','html','--url',`${interactiveBase}selected-baseline.html`,'--current-url',`${interactiveBase}selected-moon.html`,'--output-dir',selectedOutput,'--no-paint-tree']);
  const selectedReportPath=path.join(selectedOutput,'diff-report.json');
  const selectedReport=JSON.parse(readFileSync(selectedReportPath,'utf8'));
  for (const result of selectedReport.results) {
    const before=PNG.sync.read(readFileSync(path.join(selectedOutput,`compat_interactive_selected-baseline-${result.viewport}.png`)));
    const after=PNG.sync.read(readFileSync(path.join(selectedOutput,`compat_interactive_selected-moon-${result.viewport}.png`)));
    let changed=0;for(let i=0;i<before.data.length;i+=4)if(before.data[i]!==after.data[i]||before.data[i+1]!==after.data[i+1]||before.data[i+2]!==after.data[i+2]||before.data[i+3]!==after.data[i+3])changed++;
    const ratio=changed/(Math.min(before.width,640)*Math.min(before.height,576));
    console.log(`selected cells ${result.viewport}: ${changed} pixels changed (${(ratio*100).toFixed(4)}%)`);
    assert.ok(ratio<=0.0005,`${result.viewport}: selected cell visual difference exceeds 0.05%`);
  }
  await run(['diff','agent',selectedReportPath,'--no-history']);
  const findOutput=path.join(output,'find');mkdirSync(findOutput);
  await run(['diff','html','--url',`${interactiveBase}find-baseline.html`,'--current-url',`${interactiveBase}find-moon.html`,'--output-dir',findOutput,'--no-paint-tree']);
  const findReportPath=path.join(findOutput,'diff-report.json');
  const findReport=JSON.parse(readFileSync(findReportPath,'utf8'));
  for(const result of findReport.results){
    const before=PNG.sync.read(readFileSync(path.join(findOutput,`compat_interactive_find-baseline-${result.viewport}.png`)));
    const after=PNG.sync.read(readFileSync(path.join(findOutput,`compat_interactive_find-moon-${result.viewport}.png`)));
    let changed=0;for(let i=0;i<before.data.length;i+=4)if(before.data[i]!==after.data[i]||before.data[i+1]!==after.data[i+1]||before.data[i+2]!==after.data[i+2]||before.data[i+3]!==after.data[i+3])changed++;
    const ratio=changed/(Math.min(before.width,640)*Math.min(before.height,576));
    console.log(`find ${result.viewport}: ${changed} pixels changed (${(ratio*100).toFixed(4)}%)`);
    assert.ok(ratio<=0.0005,`${result.viewport}: find visual difference exceeds 0.05%`);
  }
  await run(['diff','agent',findReportPath,'--no-history']);
  await run(['scan','handlers',`${interactiveBase}find-moon.html`,'--no-ledger']);
  await run(['check','interactions',`${interactiveBase}find-moon.html`,'--reference',`${interactiveBase}find-baseline.html`,'--handlers','--no-ledger']);
  await run(['scan','handlers',`${interactiveBase}moon.html`,'--no-ledger']);
  await run(['check','interactions',`${interactiveBase}moon.html`,'--reference',`${interactiveBase}baseline.html`,'--handlers','--no-ledger']);
  for (const variant of ['moon', 'split', 'encrypted-password', 'encrypted-split', 'encrypted-ecdh', 'encrypted-ecdh-split']) {
  const variantOutput = path.join(output, variant);
  mkdirSync(variantOutput);
  await run(['diff', 'html', '--url', `${base}baseline.html`, '--current-url', `${base}${variant}.html`, '--output-dir', variantOutput, '--no-paint-tree']);
  const reportPath = path.join(variantOutput, 'diff-report.json');
  const report = JSON.parse(readFileSync(reportPath, 'utf8'));
  assert.equal(report.results.length, 3, 'expected three vlmkit viewports');
  for (const result of report.results) {
    const baseline = PNG.sync.read(readFileSync(path.join(variantOutput, `compat_visual_baseline-${result.viewport}.png`)));
    const current = PNG.sync.read(readFileSync(path.join(variantOutput, `compat_visual_${variant}-${result.viewport}.png`)));
    assert.equal(baseline.width, current.width);
    assert.equal(baseline.height, current.height);
    const sample = (80 * baseline.width + 40) * 4;
    assert.ok(baseline.data[sample + 2] > 100 && baseline.data[sample] < 100 && baseline.data[sample + 3] === 255, 'baseline capture is blank or incomplete');
    if (baseline.width > 540) {
      const svg = (280 * baseline.width + 510) * 4;
      assert.ok(baseline.data[svg] > 200 && baseline.data[svg + 1] > 150 && baseline.data[svg + 2] < 140, 'SVG was not rendered');
      let fontPixels = 0;
      for (let y = 340; y < 390; y++) for (let x = 385; x < 480; x++) {
        const i = (y * baseline.width + x) * 4;
        if (baseline.data[i] < 100 && baseline.data[i + 1] < 100 && baseline.data[i + 2] < 120) fontPixels++;
      }
      assert.ok(fontPixels > 200, 'embedded font was not rendered');
    }
    if (baseline.height > 510) {
      const group = (430 * baseline.width + 40) * 4;
      const alphaMask = (430 * baseline.width + 230) * 4;
      assert.ok(baseline.data[group] > 200 && baseline.data[group + 1] < 180, 'transparency group was not rendered');
      assert.ok(baseline.data[alphaMask + 1] > baseline.data[alphaMask] && baseline.data[alphaMask] < 200, 'alpha mask was not rendered');
      if (baseline.width > 520) {
        const luminosityMask = (430 * baseline.width + 400) * 4;
        const transparentMask = (430 * baseline.width + 480) * 4;
        assert.ok(baseline.data[luminosityMask + 1] < 220 && baseline.data[transparentMask + 1] > 245, 'luminosity mask and transfer function were not rendered');
      }
    }
    let changed = 0;
    for (let i = 0; i < baseline.data.length; i += 4) {
      if (baseline.data[i] !== current.data[i] || baseline.data[i + 1] !== current.data[i + 1] || baseline.data[i + 2] !== current.data[i + 2] || baseline.data[i + 3] !== current.data[i + 3]) changed++;
    }
    // Normalize to the visible document area, not the surrounding white viewport.
    const visibleArea = Math.min(baseline.width, 640) * Math.min(baseline.height, 600);
    const ratio = changed / visibleArea;
    console.log(`${variant} ${result.viewport}: ${changed} pixels changed (${(ratio * 100).toFixed(4)}%)`);
    assert.ok(ratio <= 0.0005, `${result.viewport}: visual difference exceeds 0.05%`);
  }
  assert.ok(report.domEquivalence.every(item => item.result.ok), 'DOM equivalence warnings');
  await run(['diff', 'agent', reportPath, '--no-history']);
  }
} finally {
  await new Promise(resolve => server.close(resolve));
}
