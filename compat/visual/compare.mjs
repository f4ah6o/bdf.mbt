import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createReadStream, mkdirSync, mkdtempSync, readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { stripVTControlCharacters } from 'node:util';
import { chromium } from 'playwright';
import { PNG } from 'pngjs';
import { verifyPageControls } from '../continuous/controls-test.mjs';
import { verifyAudioBrowser } from '../music/audio-browser-test.mjs';
import { verifyMusicBrowser } from '../music/player-browser-test.mjs';
import { verifyPiano } from '../music/piano-test.mjs';
import { verifyLazyPages } from '../continuous/lazy-test.mjs';
import { verifySheetZoom } from '../sheet/zoom-test.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const outputRoot = path.join(root, '_build/visual-diff');
mkdirSync(outputRoot, { recursive: true });
const output = mkdtempSync(path.join(outputRoot, 'run-'));
const executable = path.join(root, 'node_modules/.bin/vlmkit');
const allowed = ['/compat/visual/', '/compat/interactive/', '/compat/sheet/', '/compat/continuous/', '/compat/music/', '/node_modules/@bdfkit/', '/_build/js/debug/build/browser/'];
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
    const continuousBase=`http://127.0.0.1:${server.address().port}/compat/continuous/`;
    const regions={};
    for(const name of ['baseline','moon','split','encrypted','encrypted-split']){
      const page=await browser.newPage({viewport:{width:1280,height:720}}),errors=[];page.on('pageerror',error=>errors.push(String(error)));
      await page.goto(`${continuousBase}region-${name}.html`,{waitUntil:'networkidle'});await page.waitForFunction(()=>window.bdfStatus==='ready'||window.bdfStatus==='error');
      assert.equal(await page.evaluate(()=>window.bdfStatus),'ready',`${name}: ${await page.evaluate(()=>window.bdfError)}`);assert.deepEqual(errors,[],`${name}: continuous fixture errors`);regions[name]=page;
    }
    const continuousLayout=await regions.baseline.evaluate(()=>window.referenceLayout);
    assert.deepEqual(continuousLayout,{offsets:[0,92.5,165],width:200,height:285},'upstream flow-body layout');
    for(const args of [[0,0,200,200,1],[10,35,160,120,1.25],[0,80,200,12,1],[190,0,80,200,1],[-5,-5,200,120,2],[0,165,200,20,1],[0,400,200,20,1]]){
      const result={};for(const [name,page] of Object.entries(regions))result[name]=await page.evaluate(async args=>({count:await window.renderRegion(...args),png:document.querySelector('canvas').toDataURL(),requests:window.requests??[]}),args);
      const expected=PNG.sync.read(Buffer.from(result.baseline.png.split(',')[1],'base64'));
      for(const name of ['moon','split','encrypted','encrypted-split']){
        assert.equal(result[name].count,result.baseline.count,`${name}: visible continuous bands`);
        const actual=PNG.sync.read(Buffer.from(result[name].png.split(',')[1],'base64'));assert.deepEqual([actual.width,actual.height],[expected.width,expected.height]);
        let changed=0;for(let i=0;i<expected.data.length;i+=4)if(expected.data[i]!==actual.data[i]||expected.data[i+1]!==actual.data[i+1]||expected.data[i+2]!==actual.data[i+2]||expected.data[i+3]!==actual.data[i+3])changed++;
        assert.ok(changed/(expected.width*expected.height)<=0.0005,`${name}: continuous region ${args} differs by ${changed} pixels`);
      }
      if(args[1]===80)assert.equal(result.split.requests.length,0,'a viewport in the gap does not load parts');
      if(args[1]===165)assert.equal(result.split.requests.length,3,'a continuous viewport loads only its visible page layers');
    }
    for(const gap of [-10,-150]){
      const result={};for(const name of ['baseline','split'])result[name]=await regions[name].evaluate(async gap=>{window.setGap(gap);return{count:await window.renderRegion(0,-20,200,180,1),png:document.querySelector('canvas').toDataURL()}},gap);
      assert.equal(result.split.count,result.baseline.count,`continuous gap ${gap}: intersecting bands`);
      const reference=PNG.sync.read(Buffer.from(result.baseline.png.split(',')[1],'base64')),actual=PNG.sync.read(Buffer.from(result.split.png.split(',')[1],'base64'));
      let changed=0;for(let i=0;i<reference.data.length;i+=4)if(reference.data[i]!==actual.data[i]||reference.data[i+1]!==actual.data[i+1]||reference.data[i+2]!==actual.data[i+2]||reference.data[i+3]!==actual.data[i+3])changed++;
      assert.ok(changed/(reference.width*reference.height)<=0.0005,`continuous gap ${gap}: overlapping bands differ by ${changed} pixels`);
    }
    const invalidContinuous=await regions.moon.evaluate(async()=>{const old=document.querySelector('canvas');let rejected=0;for(const args of [[0,0,0,100,1],[0,0,100,100,0],[NaN,0,100,100,1],[0,0,9000,1,1]])try{await window.renderRegion(...args)}catch{if(document.querySelector('canvas')===old)rejected++}return rejected});
    assert.equal(invalidContinuous,4,'invalid continuous viewports preserve the current rendering');
    const invalidCredentials=await regions.encrypted.evaluate(async()=>{const {render_bdf_continuous_region_encrypted_async}=await import('/_build/js/debug/build/browser/browser.js'),data=new Uint8Array(await(await fetch('./flow-encrypted.bdf')).arrayBuffer()),host=document.querySelector('#host'),old=host.querySelector('canvas');try{await render_bdf_continuous_region_encrypted_async(host,data,'wrong',0,0,100,100,1);return false}catch{return host.querySelector('canvas')===old}});
    assert.equal(invalidCredentials,true,'wrong credentials preserve the existing continuous region');
    const encryptedEcdh=await regions.baseline.evaluate(async()=>{
      const {BdfDocument,BufferSource}=await import('@bdfkit/core'),{PageRenderer}=await import('@bdfkit/render'),bdf=await import('/_build/js/debug/build/browser/browser.js');
      const read=async file=>new Uint8Array(await(await fetch(`../visual/${file}`)).arrayBuffer()),jwk=await(await fetch('../visual/encrypted-fixture/test-private.jwk')).json();
      const privateKey=await crypto.subtle.importKey('jwk',jwk,{name:'ECDH',namedCurve:'P-256'},false,['deriveKey']),{d,...publicJwk}=jwk,publicKey=await crypto.subtle.importKey('jwk',publicJwk,{name:'ECDH',namedCurve:'P-256'},true,[]),pair={publicKey,privateKey};
      const doc=await BdfDocument.open(new BufferSource(await read('fixture.bdf'))),reference=document.createElement('canvas');reference.width=200;reference.height=150;
      await new PageRenderer(doc).renderContinuous(reference.getContext('2d'),doc.manifest.views[0],{x:20,y:30,w:200,h:150},{scale:1});
      const host=document.createElement('div');document.body.append(host);const single=await read('encrypted-fixture/ecdh.bdf'),manifest=await read('encrypted-fixture/ecdh-split/manifest.json'),loader=hash=>read(`encrypted-fixture/ecdh-split/parts/${hash}`);
      const one=await bdf.render_bdf_continuous_region_encrypted_async(host,single,pair,20,30,200,150,1),onePng=host.querySelector('canvas').toDataURL();
      const two=await bdf.render_bdf_continuous_region_encrypted_split_async(host,manifest,loader,pair,20,30,200,150,1),twoPng=host.querySelector('canvas').toDataURL();bdf.unmount_bdf(host);host.remove();
      return {one,two,onePng,twoPng,reference:reference.toDataURL()};
    });
    assert.deepEqual([encryptedEcdh.one,encryptedEcdh.two],[1,1],'P-256 encrypted continuous regions render one band');
    const ecdhReference=PNG.sync.read(Buffer.from(encryptedEcdh.reference.split(',')[1],'base64'));
    for(const name of ['onePng','twoPng']){const actual=PNG.sync.read(Buffer.from(encryptedEcdh[name].split(',')[1],'base64'));let changed=0;for(let i=0;i<ecdhReference.data.length;i+=4)if(ecdhReference.data[i]!==actual.data[i]||ecdhReference.data[i+1]!==actual.data[i+1]||ecdhReference.data[i+2]!==actual.data[i+2]||ecdhReference.data[i+3]!==actual.data[i+3])changed++;assert.ok(changed/(200*150)<=0.0005,`${name}: P-256 continuous pixels differ by ${changed}`)}
    const sheetReset=await regions.baseline.evaluate(async()=>{
      const {BdfDocument}=await import('@bdfkit/core'),{PageRenderer}=await import('@bdfkit/render'),bdf=await import('/_build/js/debug/build/browser/browser.js'),read=async path=>new Uint8Array(await(await fetch(path)).arrayBuffer());
      const metadata=JSON.parse(new TextDecoder().decode(await read('./flow-split/manifest.json'))),hash=metadata.views[0].pages[0].layers.at(-1).obj;
      metadata.views=[{id:'sheet',kind:'sheet',tile:256,cols:[[2,80]],rows:[[1,100]],tiles:{'0,0':hash}}];
      const loader=hash=>read(`./flow-split/parts/${hash}`),doc=await BdfDocument.open({manifest:async()=>metadata,stored:part=>loader(part.h)}),reference=document.createElement('canvas');reference.width=160;reference.height=100;
      await new PageRenderer(doc).renderSheet(reference.getContext('2d'),doc.manifest.views[0],{x:0,y:0,w:160,h:100},{scale:1});
      const host=document.createElement('div');document.body.append(host);const count=await bdf.render_bdf_sheet_region_split_async(host,new TextEncoder().encode(JSON.stringify(metadata)),loader,0,0,160,100,1),canvas=host.querySelector('canvas'),pixel=[...canvas.getContext('2d').getImageData(110,50,1,1).data],actual=canvas.toDataURL();bdf.unmount_bdf(host);host.remove();
      return {count,pixel,actual,reference:reference.toDataURL()};
    });
    assert.deepEqual([sheetReset.count,sheetReset.pixel],[1,[0,0,0,255]],'sheet objects start with the default black fill');
    const sheetResetReference=PNG.sync.read(Buffer.from(sheetReset.reference.split(',')[1],'base64')),sheetResetActual=PNG.sync.read(Buffer.from(sheetReset.actual.split(',')[1],'base64'));
    assert.deepEqual(sheetResetActual.data,sheetResetReference.data,'sheet default drawing state matches upstream');
    for(const page of Object.values(regions))await page.close();
    const scrollPages={};
    for(const name of ['baseline','moon']){
      const page=await browser.newPage({viewport:{width:1280,height:720}}),errors=[];page.on('pageerror',error=>errors.push(String(error)));
      await page.goto(`${continuousBase}viewer-${name}.html`,{waitUntil:'networkidle'});await page.waitForFunction(()=>window.bdfStatus==='ready'||window.bdfStatus==='error');
      assert.equal(await page.evaluate(()=>window.bdfStatus),'ready',`${name}: ${await page.evaluate(()=>window.bdfError)}`);assert.deepEqual(errors,[],`${name}: scroll fixture errors`);
      scrollPages[name]=await page.evaluate(()=>[...document.querySelectorAll('#host canvas')].map(c=>{const r=c.getBoundingClientRect();return{x:r.x,y:r.y,w:r.width,h:r.height}}));await page.close();
    }
    assert.deepEqual(scrollPages.moon,scrollPages.baseline,'scroll strips use the same page positions as the upstream viewer');
    for(const dpr of [1.5,2]){
      const pages={};
      for(const name of ['baseline','moon']){
        const page=await browser.newPage({viewport:{width:1280,height:720},deviceScaleFactor:dpr});
        await page.goto(`${continuousBase}viewer-${name}.html`,{waitUntil:'networkidle'});
        await page.waitForFunction(()=>window.bdfStatus==='ready'||window.bdfStatus==='error');
        assert.equal(await page.evaluate(()=>window.bdfStatus),'ready',`HiDPI ${name}: ${await page.evaluate(()=>window.bdfError)}`);
        pages[name]=await page.evaluate(()=>[...document.querySelectorAll('#host canvas')].map(c=>{const r=c.getBoundingClientRect();return{width:c.width,height:c.height,cssWidth:r.width,cssHeight:r.height,image:c.toDataURL()}}));
        if(name==='moon'){
          const mounted=await page.evaluate(async()=>{
            const bdf=await import('/_build/js/debug/build/browser/browser.js'),read=async file=>new Uint8Array(await(await fetch(file)).arrayBuffer());
            const single=await read('scroll.bdf'),manifest=await read('scroll-split/manifest.json'),encrypted=await read('scroll-encrypted.bdf'),locked=await read('scroll-encrypted-split/manifest.json'),results=[];
            for(const mount of [
              h=>bdf.mount_bdf_interactive_async(h,single,'single'),
              h=>bdf.mount_bdf_interactive_split_async(h,manifest,hash=>read(`scroll-split/parts/${hash}`),'single'),
              h=>bdf.mount_bdf_interactive_encrypted_async(h,encrypted,'pass','single'),
              h=>bdf.mount_bdf_interactive_encrypted_split_async(h,locked,hash=>read(`scroll-encrypted-split/parts/${hash}`),'pass','single'),
            ]){
              const host=document.createElement('div');host.style.width='200px';document.body.append(host);await mount(host);
              const canvas=host.querySelector('canvas'),layer=host.querySelector('[data-bdf-layer]'),find=await bdf.bdf_find_async(host,'Strip',0);
              results.push({bitmap:[canvas.width,canvas.height],canvas:[canvas.offsetWidth,canvas.offsetHeight],layer:[layer.offsetWidth,layer.offsetHeight],hits:find.total});
              bdf.unmount_bdf(host);host.remove();
            }
            const host=document.createElement('div');document.body.append(host);await bdf.render_bdf_continuous_region_async(host,single,0,0,100,50,1);
            const canvas=host.querySelector('canvas'),region=[canvas.width,canvas.height];bdf.unmount_bdf(host);host.remove();
            const oversized=JSON.parse(new TextDecoder().decode(manifest));oversized.views[0].pages[0].w=6000;
            const original=document.createElement('div');original.textContent='existing document';document.body.append(original);let preserved=false;
            try{await bdf.mount_bdf_split_async(original,new TextEncoder().encode(JSON.stringify(oversized)),hash=>read(`scroll-split/parts/${hash}`),'single')}catch{preserved=original.textContent==='existing document'}
            original.remove();return {results,region,preserved};
          });
          for(const result of mounted.results){assert.deepEqual(result.bitmap,[200*dpr,80*dpr],`HiDPI ${dpr}: interactive backing store`);assert.deepEqual(result.canvas,result.layer,`HiDPI ${dpr}: text layer uses CSS pixels`);assert.equal(result.hits,3,`HiDPI ${dpr}: interactive search`)}
          assert.deepEqual(mounted.region,[100,50],`HiDPI ${dpr}: explicit region scale remains independent of screen density`);
          assert.equal(mounted.preserved,true,`HiDPI ${dpr}: rejected backing store leaves the existing host intact`);
        }
        await page.close();
      }
      for(let i=0;i<pages.baseline.length;i++){
        const reference=pages.baseline[i],actual=pages.moon[i];
        assert.deepEqual([actual.width,actual.height,actual.cssWidth,actual.cssHeight],[reference.width,reference.height,reference.cssWidth,reference.cssHeight],`HiDPI ${dpr}: strip ${i} geometry`);
        const expected=PNG.sync.read(Buffer.from(reference.image.split(',')[1],'base64')),result=PNG.sync.read(Buffer.from(actual.image.split(',')[1],'base64'));
        let changed=0;for(let j=0;j<expected.data.length;j+=4)if(expected.data[j]!==result.data[j]||expected.data[j+1]!==result.data[j+1]||expected.data[j+2]!==result.data[j+2]||expected.data[j+3]!==result.data[j+3])changed++;
        assert.ok(changed/(expected.width*expected.height)<=0.0005,`HiDPI ${dpr}: strip ${i} differs in ${changed} pixels`);
      }
    }
    const spreadPages={},responsiveSpread={};
    for(const name of ['baseline','moon']){
      const page=await browser.newPage({viewport:{width:1280,height:720}}),errors=[];page.on('pageerror',error=>errors.push(String(error)));
      await page.goto(`${continuousBase}spread-${name}.html`,{waitUntil:'networkidle'});await page.waitForFunction(()=>window.bdfStatus==='ready'||window.bdfStatus==='error');
      assert.equal(await page.evaluate(()=>window.bdfStatus),'ready',`${name}: ${await page.evaluate(()=>window.bdfError)}`);assert.deepEqual(errors,[],`${name}: RTL spread fixture errors`);
      spreadPages[name]=await page.evaluate(()=>[...document.querySelectorAll('#host canvas')].slice(0,2).map(c=>{const r=c.getBoundingClientRect();return{x:r.x,y:r.y,w:r.width,h:r.height}}));
      responsiveSpread[name]=await page.evaluate(async()=>{const host=document.querySelector('#host'),result=[];for(const width of [600,300,376,220]){host.style.width=width+'px';await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));const origin=host.getBoundingClientRect();result.push([...host.querySelectorAll('canvas')].map(c=>{const r=c.getBoundingClientRect();return [r.x-origin.x,r.y-origin.y,r.width,r.height]}))}return result});
      await page.close();
    }
    assert.deepEqual(spreadPages.moon,spreadPages.baseline,'RTL spread positions match the upstream viewer');
    assert.deepEqual(responsiveSpread.moon,responsiveSpread.baseline,'all RTL spread rows follow upstream when the viewport is resized');
    const scrollPage=await browser.newPage({viewport:{width:1280,height:720}});await scrollPage.goto(`${continuousBase}viewer-moon.html`,{waitUntil:'networkidle'});
    const scrollModes=await scrollPage.evaluate(async()=>{
      const bdf=await import('/_build/js/debug/build/browser/browser.js'),read=async file=>new Uint8Array(await(await fetch(file)).arrayBuffer());
      const single=await read('scroll.bdf'),manifest=await read('scroll-split/manifest.json'),encrypted=await read('scroll-encrypted.bdf'),locked=await read('scroll-encrypted-split/manifest.json'),results=[];
      for(const [kind,mount] of [
        ['single',(h,layout)=>bdf.mount_bdf_interactive_async(h,single,layout)],
        ['split',(h,layout)=>bdf.mount_bdf_interactive_split_async(h,manifest,hash=>read(`scroll-split/parts/${hash}`),layout)],
        ['encrypted',(h,layout)=>bdf.mount_bdf_interactive_encrypted_async(h,encrypted,'pass',layout)],
        ['encrypted-split',(h,layout)=>bdf.mount_bdf_interactive_encrypted_split_async(h,locked,hash=>read(`scroll-encrypted-split/parts/${hash}`),'pass',layout)],
      ])for(const layout of ['single','spread','continuous']){
        const host=document.createElement('div');host.style.cssText='position:relative;width:200px;height:100px;overflow:auto';document.body.append(host);const count=await mount(host,layout),found=await bdf.bdf_find_async(host,'Strip',0);
        const last=await bdf.bdf_find_async(host,'Strip 3',0);
        results.push({kind,layout,count,positions:[...host.querySelectorAll('canvas')].map(c=>parseFloat(c.style.top)),total:found.total,detail:found.detail,scrollable:host.clientHeight===100&&host.scrollHeight>=300,revealed:last.total===1&&host.scrollTop>0});bdf.unmount_bdf(host);host.remove();
      }
      const sync=document.createElement('div');document.body.append(sync);const count=bdf.mount_bdf(sync,single,'spread'),positions=[...sync.querySelectorAll('canvas')].map(c=>parseFloat(c.style.top));bdf.unmount_bdf(sync);sync.remove();
      const metadata=JSON.parse(new TextDecoder().decode(manifest));metadata.views[0].pages[0].layers=[];
      const blank=document.createElement('div');document.body.append(blank);await bdf.mount_bdf_split_async(blank,new TextEncoder().encode(JSON.stringify(metadata)),hash=>read(`scroll-split/parts/${hash}`),'single');
      const background=[...blank.querySelector('canvas').getContext('2d').getImageData(0,0,1,1).data];bdf.unmount_bdf(blank);blank.remove();return {results,count,positions,background};
    });
    for(const result of scrollModes.results){assert.equal(result.count,3,`${result.kind}/${result.layout}: strip count`);assert.deepEqual(result.positions,[0,80,180],`${result.kind}/${result.layout}: strips have no gaps`);assert.equal(result.total,3,`${result.kind}/${result.layout}: strips are searchable`);assert.ok(!result.detail.startsWith('page '),`${result.kind}/${result.layout}: scroll search has no page label`);assert.ok(result.scrollable&&result.revealed,`${result.kind}/${result.layout}: constrained host scrolls to the last strip`)}
    assert.deepEqual([scrollModes.count,scrollModes.positions],[3,[0,80,180]],'synchronous scroll mount');
    assert.deepEqual(scrollModes.background,[255,255,255,255],'empty scroll strips receive the upstream white page background');await scrollPage.close();
    const resizing=await browser.newPage({viewport:{width:1280,height:720}});await resizing.goto(`${continuousBase}viewer-moon.html`,{waitUntil:'networkidle'});
    const resized=await resizing.evaluate(async()=>{
      const bdf=await import('/_build/js/debug/build/browser/browser.js'),bytes=new Uint8Array(await(await fetch('./scroll.bdf')).arrayBuffer()),host=document.createElement('div');
      host.style.cssText='width:500px;height:200px;overflow:auto';document.body.append(host);await bdf.mount_bdf_interactive_async(host,bytes,'single');
      let events=0;host.addEventListener('findchange',()=>events++);const found=await bdf.bdf_find_async(host,'Strip',0);
      const snapshot=()=>({canvas:parseFloat(host.querySelector('canvas').style.left),text:parseFloat(host.querySelector('[data-bdf-layer]').style.left),hit:parseFloat(host.querySelector('[data-bdf-hit]').style.left),scrollTop:host.scrollTop});
      const before=snapshot();host.style.width='300px';await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));const after=snapshot(),again=await bdf.bdf_find_async(host,'Strip',0);
      bdf.unmount_bdf(host);host.remove();
      const detached=document.createElement('div');detached.style.cssText='width:500px;height:200px';await bdf.mount_bdf_async(detached,bytes,'single');
      document.body.append(detached);await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));const attachedLeft=parseFloat(detached.querySelector('canvas').style.left);
      detached.remove();await new Promise(resolve=>setTimeout(resolve,0));const disposed=!detached[Symbol.for('f4ah6o.bdf.pageLayout')];bdf.unmount_bdf(detached);
      return {before,after,events,found:found.total,again:again.total,index:again.index,attachedLeft,disposed};
    });
    assert.equal(resized.found,3,'responsive search found all strips');assert.equal(resized.again,3,'responsive search retains matches');assert.equal(resized.index,0,'responsive search retains selection');
    assert.deepEqual([resized.before.canvas,resized.before.text,resized.after.canvas,resized.after.text],[150,150,50,50],'canvas and selectable text recenter together');
    assert.equal(resized.after.hit-resized.before.hit,-100,'search highlights follow the centered page');assert.equal(resized.before.scrollTop,resized.after.scrollTop,'resizing does not scroll to a match');assert.equal(resized.events,2,'resizing does not emit a search event');await resizing.close();
    assert.equal(resized.attachedLeft,150,'a document mounted while detached centers when attached');assert.equal(resized.disposed,true,'the layout observer is disposed when its host is removed');
    await verifyPageControls(browser,continuousBase,interactiveBase,base);
    await verifyLazyPages(browser,continuousBase);
    await verifyPiano(browser,base);
    await verifyAudioBrowser(browser,base);
    await verifyMusicBrowser(browser,base);
    for(const name of ['baseline','moon']){const page=await browser.newPage();await page.goto(`http://127.0.0.1:${server.address().port}/compat/music/piano-${name}.html`,{waitUntil:'networkidle'});assert.equal(await page.evaluate(()=>window.bdfStatus),'ready',`piano ${name}: ${await page.evaluate(()=>window.bdfError)}`);assert.ok(await page.locator('canvas[aria-label^="Piano roll with"]').count());await page.close()}
    const sheetBase=`http://127.0.0.1:${server.address().port}/compat/sheet/`;
    const cellFixtures={};
    for(const name of ['cells-baseline','cells-moon']){
      const page=await browser.newPage({viewport:{width:1280,height:720}}),errors=[];
      page.on('pageerror',error=>errors.push(String(error)));
      await page.goto(`${sheetBase}${name}.html`,{waitUntil:'networkidle'});
      await page.waitForFunction(()=>window.bdfStatus==='ready'||window.bdfStatus==='error');
      assert.equal(await page.evaluate(()=>window.bdfStatus),'ready',`${name}: ${await page.evaluate(()=>window.bdfError)}`);
      assert.deepEqual(errors,[],`${name}: sheet cell fixture errors`);
      cellFixtures[name]=await page.evaluate(()=>({clipboard:window.referenceClipboard??window.selectedCells,large:window.referenceFor?.({row0:0,col0:0,row1:4,col1:6}),chain:window.referenceFor?.({row0:0,col0:0,row1:5,col1:2}),box:[...document.querySelectorAll('[data-bdf-cellbox]')].map(el=>{const r=el.getBoundingClientRect();return[r.x,r.y,r.width,r.height]}),roles:[...document.querySelectorAll('[role=cell],[role=columnheader],[role=rowheader]')].map(el=>[el.textContent,el.getAttribute('role')]).sort()}));
      await page.close();
    }
    assert.deepEqual(cellFixtures['cells-moon'].clipboard,cellFixtures['cells-baseline'].clipboard,'sheet merged cells and hidden rows/columns match upstream clipboard');
    assert.deepEqual(cellFixtures['cells-moon'].roles,cellFixtures['cells-baseline'].roles,'sheet cell accessibility roles match upstream');
    assert.deepEqual(cellFixtures['cells-moon'].box,cellFixtures['cells-baseline'].box,'sheet cell selection box matches upstream');
    const dragPage=await browser.newPage({viewport:{width:1280,height:720}});
    await dragPage.goto(`${sheetBase}cells-moon.html`,{waitUntil:'networkidle'});
    await dragPage.waitForFunction(()=>window.bdfStatus==='ready'||window.bdfStatus==='error');
    assert.equal(await dragPage.evaluate(()=>window.bdfStatus),'ready','sheet cell drag fixture is ready');
    const dragBoxes=await dragPage.evaluate(()=>{getSelection().removeAllRanges();document.dispatchEvent(new Event('selectionchange'));return ['Header','End'].map(text=>{const el=[...document.querySelectorAll('[data-bdf-ordinal]')].find(s=>s.textContent===text),r=el.getBoundingClientRect();return {x:r.x,y:r.y,w:r.width,h:r.height}})});
    await dragPage.mouse.move(dragBoxes[0].x+2,dragBoxes[0].y+dragBoxes[0].h/2);await dragPage.mouse.down();
    await dragPage.mouse.move(dragBoxes[1].x+dragBoxes[1].w-2,dragBoxes[1].y+dragBoxes[1].h/2,{steps:20});await dragPage.mouse.up();
    const draggedCells=await dragPage.evaluate(async()=>{const bdf=await import('/_build/js/debug/build/browser/browser.js');return bdf.bdf_selection_cells_async(document.querySelector('#host'))});
    assert.deepEqual(draggedCells,cellFixtures['cells-baseline'].clipboard,'dragging across sheet tiles selects the matching cell rectangle');
    await dragPage.evaluate(()=>{getSelection().removeAllRanges();document.dispatchEvent(new Event('selectionchange'))});
    await dragPage.mouse.move(dragBoxes[1].x+dragBoxes[1].w-2,dragBoxes[1].y+dragBoxes[1].h/2);await dragPage.mouse.down();
    await dragPage.mouse.move(dragBoxes[0].x+2,dragBoxes[0].y+dragBoxes[0].h/2,{steps:20});await dragPage.mouse.up();
    const reverseDragged=await dragPage.evaluate(async()=>{const bdf=await import('/_build/js/debug/build/browser/browser.js');return bdf.bdf_selection_cells_async(document.querySelector('#host'))});
    assert.deepEqual(reverseDragged,cellFixtures['cells-baseline'].clipboard,'reverse dragging selects the same sheet cell rectangle');
    await dragPage.close();
    const cellsPage=await browser.newPage({viewport:{width:1280,height:720}});
    await cellsPage.goto(`${sheetBase}live-moon.html`,{waitUntil:'networkidle'});
    const sheetCells=await cellsPage.evaluate(async()=>{
      const bdf=await import('/_build/js/debug/build/browser/browser.js'),read=async file=>new Uint8Array(await(await fetch(file)).arrayBuffer());
      const waitFor=(promise,label)=>new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(new Error(label)),5000);promise.then(value=>{clearTimeout(timer);resolve(value)},error=>{clearTimeout(timer);reject(error)})});
      const single=await read('cells.bdf'),manifest=await read('cells-split/manifest.json'),encrypted=await read('cells-encrypted.bdf'),locked=await read('cells-encrypted-split/manifest.json'),results=[];
      for(const [kind,mount] of [
        ['single',host=>bdf.mount_bdf_interactive_async(host,single,'single')],
        ['split',host=>bdf.mount_bdf_interactive_split_async(host,manifest,h=>read(`cells-split/parts/${h}`),'single')],
        ['encrypted',host=>bdf.mount_bdf_interactive_encrypted_async(host,encrypted,'pass','single')],
        ['encrypted-split',host=>bdf.mount_bdf_interactive_encrypted_split_async(host,locked,h=>read(`cells-encrypted-split/parts/${h}`),'pass','single')],
      ]){
        const host=document.createElement('div');host.style.cssText='position:relative;overflow:auto;width:400px;height:300px';document.body.append(host);await mount(host);
        const spans=[...host.querySelectorAll('[data-bdf-ordinal]')],first=spans.find(s=>s.textContent==='Header'),last=spans.find(s=>s.textContent==='End');
        const one=document.createRange();one.setStart(first.firstChild,0);one.setEnd(first.firstChild,3);getSelection().removeAllRanges();getSelection().addRange(one);document.dispatchEvent(new Event('selectionchange'));
        const same=bdf.bdf_selection_cells(host)==null&&(await bdf.bdf_selection_cells_async(host))==null;
        const range=document.createRange();range.setStart(first.firstChild,0);range.setEnd(last.firstChild,last.textContent.length);getSelection().removeAllRanges();getSelection().addRange(range);document.dispatchEvent(new Event('selectionchange'));
        const value=await bdf.bdf_selection_cells_async(host),sync=bdf.bdf_selection_cells(host),copy=new ClipboardEvent('copy',{bubbles:true,cancelable:true,clipboardData:new DataTransfer()}),cut=new ClipboardEvent('cut',{bubbles:true,cancelable:true,clipboardData:new DataTransfer()});host.dispatchEvent(copy);host.dispatchEvent(cut);
        const beforeBox=host.querySelector('[data-bdf-cellbox]').getBoundingClientRect().width,canvas=host.querySelector('canvas'),frame=Number(canvas.dataset.bdfSheetFrame);host.scrollLeft=248;host.dispatchEvent(new Event('scroll'));
        await new Promise((resolve,reject)=>{const timeout=setTimeout(()=>reject(new Error('selected cells scroll timeout')),5000);const check=()=>{if(Number(canvas.dataset.bdfSheetFrame)>frame){clearTimeout(timeout);resolve()}else requestAnimationFrame(check)};check()});
        const afterBox=host.querySelector('[data-bdf-cellbox]').getBoundingClientRect().width;
        const wide=spans.find(s=>s.textContent==='Wide'),chainRange=document.createRange();chainRange.setStart(first.firstChild,0);chainRange.setEnd(wide.firstChild,wide.textContent.length);getSelection().removeAllRanges();getSelection().addRange(chainRange);document.dispatchEvent(new Event('selectionchange'));const chain=await bdf.bdf_selection_cells_async(host);
        results.push({kind,same,value,sync,chain,boxExpanded:afterBox>beforeBox,copy:{text:copy.clipboardData.getData('text/plain'),html:copy.clipboardData.getData('text/html'),handled:copy.defaultPrevented},cut:{text:cut.clipboardData.getData('text/plain'),html:cut.clipboardData.getData('text/html'),handled:cut.defaultPrevented}});
        getSelection().removeAllRanges();bdf.unmount_bdf(host);host.remove();
      }
      const metadata=JSON.parse(new TextDecoder().decode(manifest)),middle=metadata.views[0].tiles['1,0'];let block=false,release,started;
      const gate=new Promise(resolve=>release=resolve),fetchStarted=new Promise(resolve=>started=resolve),loader=async hash=>{if(block&&hash===middle){started();await gate}return read(`cells-split/parts/${hash}`)};
      const host=document.createElement('div');host.style.cssText='position:relative;overflow:auto;width:100px;height:120px';document.body.append(host);await bdf.mount_bdf_interactive_split_async(host,manifest,loader,'single');
      const first=[...host.querySelectorAll('[data-bdf-ordinal]')].find(s=>s.textContent==='Header'),canvas=host.querySelector('canvas'),frame=Number(canvas.dataset.bdfSheetFrame);host.scrollLeft=512;host.dispatchEvent(new Event('scroll'));
      await new Promise((resolve,reject)=>{const timeout=setTimeout(()=>reject(new Error('cells scroll timeout')),5000);const check=()=>{if(Number(canvas.dataset.bdfSheetFrame)>frame){clearTimeout(timeout);resolve()}else requestAnimationFrame(check)};check()});
      const last=[...host.querySelectorAll('[data-bdf-ordinal]')].find(s=>s.textContent==='Far');block=true;
      const range=document.createRange();range.setStart(first.firstChild,0);range.setEnd(last.firstChild,last.textContent.length);getSelection().removeAllRanges();getSelection().addRange(range);document.dispatchEvent(new Event('selectionchange'));await waitFor(fetchStarted,'sheet cells did not request the missing tile');
      let pending=false;try{bdf.bdf_selection_cells(host)}catch{pending=true}
      const originalClipboard=Object.getOwnPropertyDescriptor(navigator,'clipboard'),originalItem=window.ClipboardItem;let written;
      window.ClipboardItem=class {constructor(types){this.types=types}};
      Object.defineProperty(navigator,'clipboard',{configurable:true,value:{write(items){written=Promise.all([items[0].types['text/plain'],items[0].types['text/html']]).then(async([plain,html])=>({text:await plain.text(),html:await html.text()}));return written.then(()=>{})}}});
      const copy=new ClipboardEvent('copy',{bubbles:true,cancelable:true,clipboardData:new DataTransfer()}),asyncValue=bdf.bdf_selection_cells_async(host);host.dispatchEvent(copy);release();
      const large=await asyncValue,delayedCopy=await written;
      if(originalClipboard)Object.defineProperty(navigator,'clipboard',originalClipboard);else delete navigator.clipboard;window.ClipboardItem=originalItem;
      const delayed={pending,handled:copy.defaultPrevented,large,delayedCopy};getSelection().removeAllRanges();bdf.unmount_bdf(host);host.remove();
      let unblock,begin;const wait=new Promise(resolve=>unblock=resolve),startedAgain=new Promise(resolve=>begin=resolve);let pause=false;
      const fallbackLoader=async hash=>{if(pause&&hash===middle){begin();await wait}return read(`cells-split/parts/${hash}`)};
      const fallback=document.createElement('div');fallback.style.cssText='position:relative;overflow:auto;width:100px;height:120px';document.body.append(fallback);await bdf.mount_bdf_interactive_split_async(fallback,manifest,fallbackLoader,'single');
      const start=[...fallback.querySelectorAll('[data-bdf-ordinal]')].find(s=>s.textContent==='Header'),fallbackCanvas=fallback.querySelector('canvas'),before=Number(fallbackCanvas.dataset.bdfSheetFrame);fallback.scrollLeft=512;fallback.dispatchEvent(new Event('scroll'));
      await new Promise((resolve,reject)=>{const timeout=setTimeout(()=>reject(new Error('fallback cells scroll timeout')),5000);const check=()=>{if(Number(fallbackCanvas.dataset.bdfSheetFrame)>before){clearTimeout(timeout);resolve()}else requestAnimationFrame(check)};check()});
      const finish=[...fallback.querySelectorAll('[data-bdf-ordinal]')].find(s=>s.textContent==='Far');pause=true;
      const selection=document.createRange();selection.setStart(start.firstChild,0);selection.setEnd(finish.firstChild,finish.textContent.length);getSelection().removeAllRanges();getSelection().addRange(selection);
      const errors=[];fallback.addEventListener('error',event=>{errors.push(String(event.detail));event.preventDefault()});
      const oldClipboard=Object.getOwnPropertyDescriptor(navigator,'clipboard'),oldItem=window.ClipboardItem;Object.defineProperty(navigator,'clipboard',{configurable:true,value:undefined});window.ClipboardItem=undefined;
      const early=new ClipboardEvent('copy',{bubbles:true,cancelable:true,clipboardData:new DataTransfer()});fallback.dispatchEvent(early);await waitFor(startedAgain,'sheet fallback did not start loading');unblock();const loaded=await bdf.bdf_selection_cells_async(fallback);
      const retry=new ClipboardEvent('copy',{bubbles:true,cancelable:true,clipboardData:new DataTransfer()});fallback.dispatchEvent(retry);
      if(oldClipboard)Object.defineProperty(navigator,'clipboard',oldClipboard);else delete navigator.clipboard;window.ClipboardItem=oldItem;
      const fallbackResult={prevented:early.defaultPrevented,empty:early.clipboardData.getData('text/plain')==='',error:errors.some(error=>error.includes('copy again')),loaded,retry:{text:retry.clipboardData.getData('text/plain'),html:retry.clipboardData.getData('text/html'),handled:retry.defaultPrevented}};
      getSelection().removeAllRanges();bdf.unmount_bdf(fallback);fallback.remove();
      let resume,startedUnmount;const stopped=new Promise(resolve=>resume=resolve),waiting=new Promise(resolve=>startedUnmount=resolve);let hold=false;const unmountRequests=[];
      const unmountLoader=async hash=>{unmountRequests.push(hash);if(hold&&hash===middle){startedUnmount();await stopped}return read(`cells-split/parts/${hash}`)};
      const detached=document.createElement('div');detached.style.cssText='position:relative;overflow:auto;width:100px;height:120px';document.body.append(detached);await bdf.mount_bdf_interactive_split_async(detached,manifest,unmountLoader,'single');
      const anchor=[...detached.querySelectorAll('[data-bdf-ordinal]')].find(s=>s.textContent==='Header'),detachedCanvas=detached.querySelector('canvas'),oldFrame=Number(detachedCanvas.dataset.bdfSheetFrame);detached.scrollLeft=512;detached.dispatchEvent(new Event('scroll'));
      await new Promise((resolve,reject)=>{const timeout=setTimeout(()=>reject(new Error('unmount cells scroll timeout')),5000);const check=()=>{if(Number(detachedCanvas.dataset.bdfSheetFrame)>oldFrame){clearTimeout(timeout);resolve()}else requestAnimationFrame(check)};check()});
      const end=[...detached.querySelectorAll('[data-bdf-ordinal]')].find(s=>s.textContent==='Far');hold=true;unmountRequests.length=0;
      const pendingRange=document.createRange();pendingRange.setStart(anchor.firstChild,0);pendingRange.setEnd(end.firstChild,end.textContent.length);getSelection().removeAllRanges();getSelection().addRange(pendingRange);document.dispatchEvent(new Event('selectionchange'));const pendingCells=bdf.bdf_selection_cells_async(detached).then(()=>false,()=>true);await waitFor(waiting,'sheet unmount test did not start loading');
      let lateErrors=0,unhandled=0;detached.addEventListener('error',event=>{lateErrors++;event.preventDefault()});const onUnhandled=event=>{unhandled++;event.preventDefault()};window.addEventListener('unhandledrejection',onUnhandled);
      const priorClipboard=Object.getOwnPropertyDescriptor(navigator,'clipboard'),priorItem=window.ClipboardItem;Object.defineProperty(navigator,'clipboard',{configurable:true,value:{write:async()=>{}}});window.ClipboardItem=class {constructor(){throw new TypeError('unsupported ClipboardItem')}};
      const refused=new ClipboardEvent('copy',{bubbles:true,cancelable:true,clipboardData:new DataTransfer()});detached.dispatchEvent(refused);const constructorErrors=lateErrors;lateErrors=0;
      bdf.unmount_bdf(detached);resume();const cancelled=await pendingCells;await new Promise(resolve=>setTimeout(resolve,0));
      if(priorClipboard)Object.defineProperty(navigator,'clipboard',priorClipboard);else delete navigator.clipboard;window.ClipboardItem=priorItem;window.removeEventListener('unhandledrejection',onUnhandled);
      const unmountResult={cancelled,lateErrors,unhandled,constructorErrors,refused:refused.defaultPrevented,empty:!detached.childElementCount,loads:unmountRequests.length};detached.remove();
      return {results,delayed,fallbackResult,unmountResult};
    });
    for(const result of sheetCells.results){
      assert.equal(result.same,true,`${result.kind}: selecting within one sheet cell remains text selection`);
      assert.deepEqual(result.value,cellFixtures['cells-baseline'].clipboard,`${result.kind}: selected sheet clipboard matches upstream`);
      assert.deepEqual(result.sync,result.value,`${result.kind}: synchronous clipboard after loading`);
      assert.deepEqual(result.chain,cellFixtures['cells-baseline'].chain,`${result.kind}: intersecting merged cells expand the selection transitively`);
      assert.equal(result.boxExpanded,true,`${result.kind}: sheet selection highlight updates as tiles appear`);
      assert.deepEqual(result.copy,{...result.value,handled:true},`${result.kind}: sheet copy`);
      assert.deepEqual(result.cut,{...result.value,handled:true},`${result.kind}: sheet cut`);
    }
    assert.equal(sheetCells.delayed.pending,true,'incomplete sheet cell data is not returned synchronously');
    assert.equal(sheetCells.delayed.handled,true,'copy waits for missing sheet tiles');
    assert.deepEqual(sheetCells.delayed.large,cellFixtures['cells-baseline'].large,'selection across unvisited tiles includes all cells');
    assert.deepEqual(sheetCells.delayed.delayedCopy,sheetCells.delayed.large,'deferred native clipboard contains the complete range');
    assert.ok(sheetCells.fallbackResult.prevented&&sheetCells.fallbackResult.empty&&sheetCells.fallbackResult.error,'unsupported asynchronous clipboard does not copy an incomplete range');
    assert.deepEqual(sheetCells.fallbackResult.loaded,cellFixtures['cells-baseline'].large,'fallback loads the complete selection');
    assert.deepEqual(sheetCells.fallbackResult.retry,{...sheetCells.fallbackResult.loaded,handled:true},'copy succeeds after asynchronous loading in browsers without ClipboardItem');
    assert.deepEqual(sheetCells.unmountResult,{cancelled:true,lateErrors:0,unhandled:0,constructorErrors:1,refused:true,empty:true,loads:1},'clipboard rejection and unmount cancel pending cell loading cleanly');
    await cellsPage.close();
    const sheetInteractive=await browser.newPage({viewport:{width:1280,height:720}});
    await sheetInteractive.goto(`${sheetBase}live-moon.html`,{waitUntil:'networkidle'});
    const sheetText=await sheetInteractive.evaluate(async()=>{
      const bdf=await import('/_build/js/debug/build/browser/browser.js');
      const bytes=async file=>new Uint8Array(await (await fetch(file)).arrayBuffer());
      const single=await bytes('fixture.bdf'),manifest=await bytes('split/manifest.json');
      const encrypted=await bytes('encrypted.bdf'),lockedManifest=await bytes('encrypted-split/manifest.json');
      const {BdfDocument,BufferSource,TextSearch}=await import('/node_modules/@bdfkit/core/dist/index.js');
      const upstream=await BdfDocument.open(new BufferSource(single));
      const upstreamSearch=new TextSearch(await upstream.textIndex(upstream.manifest.views[0]));
      const expectedTileHits=upstreamSearch.search('Tile').length,expectedDistantHits=upstreamSearch.search('Tile 2,1').length;
      const results=[];
      for(const [kind,mount] of [
        ['single',host=>bdf.mount_bdf_interactive_async(host,single,'single')],
        ['split',host=>bdf.mount_bdf_interactive_split_async(host,manifest,hash=>bytes(`split/parts/${hash}`),'single')],
        ['encrypted',host=>bdf.mount_bdf_interactive_encrypted_async(host,encrypted,'pass','single')],
        ['encrypted-split',host=>bdf.mount_bdf_interactive_encrypted_split_async(host,lockedManifest,hash=>bytes(`encrypted-split/parts/${hash}`),'pass','single')],
      ]) {
        const host=document.createElement('div');host.style.cssText='position:relative;overflow:auto;width:400px;height:300px';document.body.append(host);
        await mount(host);
        const tile=(x,y)=>host.querySelector(`[data-bdf-sheet-tile="${x},${y}"]`);
        const first=tile(0,0)?.querySelector('span'),second=tile(1,0)?.querySelector('span');
        const range=document.createRange();range.setStart(first.firstChild,0);range.setEnd(second.firstChild,second.textContent.length);
        getSelection().removeAllRanges();getSelection().addRange(range);
        const text=bdf.bdf_selection_text(host);
        const copy=new ClipboardEvent('copy',{bubbles:true,cancelable:true,clipboardData:new DataTransfer()});host.dispatchEvent(copy);
        const r=first.getBoundingClientRect(),point=document.elementFromPoint(r.x+r.width/2,r.y+r.height/2);
        const before=Number(host.querySelector('canvas').dataset.bdfSheetFrame);host.scrollLeft=248;host.scrollTop=204;host.dispatchEvent(new Event('scroll'));
        await new Promise((resolve,reject)=>{const timeout=setTimeout(()=>reject(new Error('interactive sheet scroll timeout')),5000);const check=()=>{if(Number(host.querySelector('canvas').dataset.bdfSheetFrame)>before){clearTimeout(timeout);resolve()}else requestAnimationFrame(check)};check()});
        const retained=bdf.bdf_selection_text(host);
        const found=await bdf.bdf_find_async(host,'Tile',0),next=await bdf.bdf_find_async(host,'Tile',1),previous=await bdf.bdf_find_async(host,'Tile',-1);
        bdf.bdf_open_find(host);host.querySelector('input').value='Tile';host.querySelector('[aria-label="Next match"]').click();
        await new Promise((resolve,reject)=>{const timeout=setTimeout(()=>reject(new Error('sheet next button timeout')),5000);const check=()=>{if(host.querySelector('[role=status]')?.textContent.startsWith('2 / 6')){clearTimeout(timeout);resolve()}else requestAnimationFrame(check)};check()});
        host.querySelector('[aria-label="Previous match"]').click();
        await new Promise((resolve,reject)=>{const timeout=setTimeout(()=>reject(new Error('sheet previous button timeout')),5000);const check=()=>{if(host.querySelector('[role=status]')?.textContent.startsWith('1 / 6')){clearTimeout(timeout);resolve()}else requestAnimationFrame(check)};check()});
        const distant=await bdf.bdf_find_async(host,'Tile 2,1',1),empty=await bdf.bdf_find_async(host,'missing',0);
        bdf.bdf_open_find(host);const input=host.querySelector('[role=search] input');input.value='Tile 2,1';input.dispatchEvent(new Event('input',{bubbles:true}));
        await new Promise((resolve,reject)=>{const timeout=setTimeout(()=>reject(new Error('sheet search bar timeout')),5000);const check=()=>{if(host.querySelector('[role=status]')?.textContent.startsWith('1 / 1')){clearTimeout(timeout);resolve()}else requestAnimationFrame(check)};check()});
        const status=host.querySelector('[role=status]').textContent,marked=host.querySelectorAll('[data-bdf-hit]').length;
        bdf.bdf_clear_find(host);
        results.push({kind,text,copied:copy.clipboardData.getData('text/plain'),prevented:copy.defaultPrevented,point:point===first,retained,newTile:!!tile(2,1),found:[found.index,found.total,expectedTileHits],next:next.index,previous:previous.index,distant:[distant.index,distant.total,expectedDistantHits,distant.rects.length],empty:empty.total,status,marked,cleared:!host.querySelector('[data-bdf-hits]')});
        getSelection().removeAllRanges();bdf.unmount_bdf(host);host.remove();
      }
      const host=document.createElement('div');host.style.cssText='position:relative;overflow:auto;width:400px;height:300px';document.body.append(host);
      const getContext=HTMLCanvasElement.prototype.getContext;
      try {
        HTMLCanvasElement.prototype.getContext=()=>null;
        let rejected=false;try{await bdf.mount_bdf_interactive_async(host,single,'single')}catch{rejected=true}
        results.push({kind:'failure-cleanup',rejected,copyReleased:!host[Symbol.for('f4ah6o.bdf.copy')],empty:!host.childElementCount});
      } finally {HTMLCanvasElement.prototype.getContext=getContext;bdf.unmount_bdf(host);host.remove()}
      return results;
    });
    const failureCleanup=sheetText.pop();
    assert.deepEqual(failureCleanup,{kind:'failure-cleanup',rejected:true,copyReleased:true,empty:true},'failed interactive sheet releases its copy handler');
    for(const result of sheetText){
      assert.equal(result.text,'Tile 0,0\nTile 1,0',`${result.kind}: selection across sheet tiles`);
      assert.equal(result.copied,result.text,`${result.kind}: sheet clipboard`);
      assert.equal(result.prevented,true,`${result.kind}: clipboard event handled`);
      assert.equal(result.point,true,`${result.kind}: text layer receives pointer events`);
      assert.equal(result.retained,result.text,`${result.kind}: selection survives scrolling`);
      assert.equal(result.newTile,true,`${result.kind}: scrolling loads another text tile`);
      assert.deepEqual(result.found,[0,6,6],`${result.kind}: sheet index matches upstream`);
      assert.deepEqual([result.next,result.previous],[1,0],`${result.kind}: search navigation`);
      assert.deepEqual(result.distant,[0,1,1,1],`${result.kind}: locate an offscreen hit`);
      assert.equal(result.empty,0,`${result.kind}: absent text has no matches`);
      assert.ok(result.status.startsWith('1 / 1')&&result.marked>0&&result.cleared,`${result.kind}: search bar, highlights and clear`);
    }
    const indexedSheet=await sheetInteractive.evaluate(async()=>{
      const bdf=await import('/_build/js/debug/build/browser/browser.js');
      const read=async file=>new Uint8Array(await (await fetch(file)).arrayBuffer());
      const metadata=JSON.parse(new TextDecoder().decode(await read('split/manifest.json'))),hash='11111111111111111111111111111111';
      const a=new TextEncoder().encode('Tile 2,0'),b=new TextEncoder().encode('Tile 2,1');
      const index=new Uint8Array([66,84,88,84,1,0,2,2,0,0,2,a.length,...a,2,1,0,2,b.length,...b]);
      metadata.views[0].textIndex=hash;metadata.parts.push({h:hash,t:'idx',enc:'identity',len:index.length,size:index.length,off:0});
      const encoded=new TextEncoder().encode(JSON.stringify(metadata)),requests=[];
      let unblock;const gate=new Promise(resolve=>unblock=resolve);let blocked=false;
      const loader=async part=>{requests.push(part);if(part===hash){if(blocked)await gate;return index}return read(`split/parts/${part}`)};
      const host=document.createElement('div');host.style.cssText='position:relative;overflow:auto;width:400px;height:300px';document.body.append(host);
      await bdf.mount_bdf_interactive_split_async(host,encoded,loader,'single');
      requests.length=0;const noHit=await bdf.bdf_find_async(host,'absent',0);
      const noHitLoads=requests.slice();requests.length=0;
      const found=await bdf.bdf_find_async(host,'Tile 2,1',0),hitLoads=requests.slice();
      bdf.unmount_bdf(host);host.remove();
      const raced=document.createElement('div');raced.style.cssText='position:relative;overflow:auto;width:400px;height:300px';document.body.append(raced);
      await bdf.mount_bdf_interactive_split_async(raced,encoded,loader,'single');blocked=true;
      const changes=[];raced.addEventListener('findchange',event=>changes.push(event.detail.query));
      const old=bdf.bdf_find_async(raced,'Tile 2,0',0),latest=bdf.bdf_find_async(raced,'Tile 2,1',0);
      unblock();await Promise.all([old,latest]);
      const lastQuery=changes.at(-1),oldPublished=changes.includes('Tile 2,0');
      bdf.unmount_bdf(raced);raced.remove();
      const fontCount=()=>[...document.fonts].filter(face=>face.family.startsWith('bdf-')).length,initialFonts=fontCount();
      const detached=document.createElement('div');detached.style.cssText='position:relative;overflow:auto;width:400px;height:300px';document.body.append(detached);
      let release,started;const paused=new Promise(resolve=>release=resolve),startedFetch=new Promise(resolve=>started=resolve),detachedRequests=[];
      const slowLoader=async part=>{detachedRequests.push(part);if(part===hash){started();await paused;return index}return read(`split/parts/${part}`)};
      await bdf.mount_bdf_interactive_split_async(detached,encoded,slowLoader,'single');detachedRequests.length=0;
      const pending=bdf.bdf_find_async(detached,'Tile 2,1',0);await startedFetch;bdf.unmount_bdf(detached);release();await pending;
      const detachedClean=fontCount()===initialFonts&&!detached.childElementCount&&!detached[Symbol.for('f4ah6o.bdf.find')]&&!detachedRequests.includes(metadata.views[0].tiles['2,1']);detached.remove();
      const retry=document.createElement('div');retry.style.cssText='position:relative;overflow:auto;width:200px;height:200px';document.body.append(retry);let failIndex=true;
      const retryLoader=async part=>{if(part===hash){if(failIndex)throw new Error('index unavailable');return index}return read(`split/parts/${part}`)};
      await bdf.mount_bdf_interactive_split_async(retry,encoded,retryLoader,'single');let failed=false;
      try{await bdf.bdf_find_async(retry,'Tile 2,1',0)}catch{failed=!!retry.querySelector('[data-bdf-sheet-frame]')}
      failIndex=false;const retried=await bdf.bdf_find_async(retry,'Tile 2,1',0);bdf.unmount_bdf(retry);retry.remove();
      const bare=structuredClone(metadata);delete bare.views[0].textIndex;bare.parts=bare.parts.filter(part=>part.h!==hash);
      const fallback=document.createElement('div');fallback.style.cssText='position:relative;overflow:auto;width:200px;height:200px';document.body.append(fallback);
      const fallbackRequests=[],fallbackLoader=async part=>{fallbackRequests.push(part);return read(`split/parts/${part}`)};
      await bdf.mount_bdf_interactive_split_async(fallback,new TextEncoder().encode(JSON.stringify(bare)),fallbackLoader,'single');fallbackRequests.length=0;
      const fallbackHit=await bdf.bdf_find_async(fallback,'Tile 0,0',0),firstLoads=fallbackRequests.slice();fallbackRequests.length=0;
      const fontHit=await bdf.bdf_find_async(fallback,'Tile 1,0',0),fontLoads=fallbackRequests.slice();bdf.unmount_bdf(fallback);fallback.remove();
      return {noHit:noHit.total,noHitLoads,hit:found.total,rects:found.rects.length,hitLoads,hash,target:metadata.views[0].tiles['2,1'],other:metadata.views[0].tiles['2,0'],lastQuery,oldPublished,detachedClean,failed,retried:retried.total,fallbackHit:fallbackHit.total,fontHit:fontHit.total,firstLoads,fontLoads,font:metadata.parts.find(part=>part.t==='font').h,image:metadata.parts.find(part=>part.t==='img').h};
    });
    assert.equal(indexedSheet.noHit,0,'stored sheet index is used');
    assert.deepEqual(indexedSheet.noHitLoads,[indexedSheet.hash],'a stored index search does not load tiles when there is no hit');
    assert.equal(indexedSheet.hit,1,'stored index finds an offscreen tile');
    assert.equal(indexedSheet.rects,1,'offscreen indexed hit is located');
    assert.ok(indexedSheet.hitLoads.includes(indexedSheet.target)&&!indexedSheet.hitLoads.includes(indexedSheet.other),'only the selected offscreen tile is loaded for hit measurement');
    assert.equal(indexedSheet.lastQuery,'Tile 2,1','latest overlapping sheet query wins');
    assert.equal(indexedSheet.oldPublished,false,'superseded sheet search is not published');
    assert.equal(indexedSheet.detachedClean,true,'unmount cancels pending sheet search before loading or retaining resources');
    assert.ok(indexedSheet.failed&&indexedSheet.retried===1,'failed index reads leave the sheet mounted and can be retried');
    assert.equal(indexedSheet.fallbackHit,1,'fallback sheet index searches tile text');
    assert.ok(!indexedSheet.firstLoads.includes(indexedSheet.font)&&!indexedSheet.firstLoads.includes(indexedSheet.image),'building a fallback index does not load unrelated fonts or images');
    assert.ok(indexedSheet.fontHit===1&&indexedSheet.fontLoads.includes(indexedSheet.font)&&!indexedSheet.fontLoads.includes(indexedSheet.image),'locating a hit loads its font without loading its image');
    await sheetInteractive.close();
    await verifySheetZoom(browser,sheetBase);
    for(const name of ['find-baseline','find-moon']){
      const page=await browser.newPage({viewport:{width:1280,height:720}}),errors=[];
      page.on('pageerror',error=>errors.push(String(error)));
      await page.goto(`${sheetBase}${name}.html`,{waitUntil:'networkidle'});
      await page.waitForFunction(()=>window.bdfStatus==='ready'||window.bdfStatus==='error');
      assert.equal(await page.evaluate(()=>window.bdfStatus),'ready',`${name}: ${await page.evaluate(()=>window.bdfError)}`);
      assert.deepEqual(errors,[],`${name}: search fixture browser errors`);
      assert.ok(await page.locator('[data-bdf-hit]').count()>=1,`${name}: selected match is marked`);
      await page.close();
    }
    const sheetPages={};
    for(const name of ['baseline','moon','split']){
      const page=await browser.newPage({viewport:{width:1280,height:720}}),errors=[];
      page.on('pageerror',error=>errors.push(String(error)));
      await page.goto(`${sheetBase}${name}.html`,{waitUntil:'networkidle'});
      await page.waitForFunction(()=>window.bdfStatus==='ready'||window.bdfStatus==='error');
      assert.equal(await page.evaluate(()=>window.bdfStatus),'ready',`${name}: ${await page.evaluate(()=>window.bdfError)}`);
      assert.deepEqual(errors,[],`${name}: sheet browser errors`);sheetPages[name]=page;
    }
    const scenarios=[[0,0,400,300,1],[320,32,260,200,1.25],[256,256,256,192,1],[0,0,200,200,1],[1200,900,200,100,1]];
    for(const args of scenarios){
      const rendered={};
      for(const [name,page] of Object.entries(sheetPages))rendered[name]=await page.evaluate(async args=>{const count=await window.renderRegion(...args);return{count,png:document.querySelector('canvas').toDataURL(),requests:window.requests??[]}},args);
      const reference=PNG.sync.read(Buffer.from(rendered.baseline.png.split(',')[1],'base64'));
      for(const name of ['moon','split']){
        assert.equal(rendered[name].count,rendered.baseline.count,`${name}: visible sheet tile count`);
        const actual=PNG.sync.read(Buffer.from(rendered[name].png.split(',')[1],'base64'));
        assert.deepEqual([actual.width,actual.height],[reference.width,reference.height],`${name}: sheet canvas size`);
        let changed=0;for(let i=0;i<reference.data.length;i+=4)if(reference.data[i]!==actual.data[i]||reference.data[i+1]!==actual.data[i+1]||reference.data[i+2]!==actual.data[i+2]||reference.data[i+3]!==actual.data[i+3])changed++;
        assert.ok(changed/(reference.width*reference.height)<=0.0005,`${name}: sheet region ${args} differs in ${changed} pixels`);
      }
      if(args[0]===0&&args[2]===200)assert.equal(rendered.split.requests.length,1,'split sheet loads only its visible tile');
      if(args[0]===1200)assert.equal(rendered.split.requests.length,0,'empty sheet region loads no tiles');
    }
    const invalidSheet=await sheetPages.moon.evaluate(async()=>{const old=document.querySelector('canvas');let failed=0;for(const args of [[0,0,0,100,1],[0,0,100,100,0],[0,0,9000,1,1],[NaN,0,100,100,1]]){try{await window.renderRegion(...args)}catch{if(document.querySelector('canvas')===old)failed++}}return failed});
    assert.equal(invalidSheet,4,'invalid sheet regions reject without replacing the previous rendering');
    for(const page of Object.values(sheetPages))await page.close();
    const liveSheets={};
    for(const name of ['baseline','moon','split']){
      const page=await browser.newPage({viewport:{width:1280,height:720}}),errors=[];
      page.on('pageerror',error=>errors.push(String(error)));
      await page.goto(`${sheetBase}live-${name}.html`,{waitUntil:'networkidle'});
      await page.waitForFunction(()=>window.bdfStatus==='ready'||window.bdfStatus==='error');
      assert.equal(await page.evaluate(()=>window.bdfStatus),'ready',`live ${name}: ${await page.evaluate(()=>window.bdfError)}`);
      assert.deepEqual(errors,[],`live ${name}: browser errors`);liveSheets[name]=page;
    }
    const initialRequests=await liveSheets.split.evaluate(()=>({requests:window.requests,tiles:window.metadata.views[0].tiles}));
    assert.ok(!initialRequests.requests.includes(initialRequests.tiles['2,0']),'offscreen sheet tiles are not fetched on mount');
    assert.equal(new Set(initialRequests.requests).size,initialRequests.requests.length,'visible parts are not fetched twice');
    let sheetInitial;
    for(const change of [{x:0,y:0},{x:200,y:132},{width:300,height:200}]){
      const frames={};
      for(const [name,page] of Object.entries(liveSheets)){
        await page.evaluate(change=>{const h=document.querySelector('#host');if(change.width){h.style.width=change.width+'px';h.style.height=change.height+'px'}else h.scrollTo(change.x,change.y)},change);
        await page.waitForFunction(()=>{const h=document.querySelector('#host'),c=h.querySelector('canvas');return c?.dataset.bdfSheetViewport===JSON.stringify([h.scrollLeft,h.scrollTop,h.clientWidth,h.clientHeight])});
        const sticky=await page.evaluate(()=>{const h=document.querySelector('#host').getBoundingClientRect(),c=document.querySelector('#host canvas').getBoundingClientRect();return{x:c.left-h.left,y:c.top-h.top}});
        assert.ok(Math.abs(sticky.x)<1&&Math.abs(sticky.y)<1,`live ${name}: sheet canvas moved out of the viewport`);
        frames[name]=await page.evaluate(()=>document.querySelector('#host canvas').toDataURL());
      }
      const reference=PNG.sync.read(Buffer.from(frames.baseline.split(',')[1],'base64'));
      if(change.x===0)sheetInitial=frames.baseline;
      for(const name of ['moon','split']){
        const actual=PNG.sync.read(Buffer.from(frames[name].split(',')[1],'base64'));
        assert.deepEqual([actual.width,actual.height],[reference.width,reference.height],`live ${name}: canvas size`);
        let changed=0;for(let i=0;i<reference.data.length;i+=4)if(reference.data[i]!==actual.data[i]||reference.data[i+1]!==actual.data[i+1]||reference.data[i+2]!==actual.data[i+2]||reference.data[i+3]!==actual.data[i+3])changed++;
        assert.ok(changed/(reference.width*reference.height)<=0.0005,`live ${name}: viewport ${JSON.stringify(change)} differs in ${changed} pixels`);
      }
    }
    const lazyRequests=await liveSheets.split.evaluate(()=>({requests:window.requests,tiles:window.metadata.views[0].tiles}));
    assert.ok(lazyRequests.requests.includes(lazyRequests.tiles['2,0']),'scrolling fetches newly visible tiles');
    assert.equal(new Set(lazyRequests.requests).size,lazyRequests.requests.length,'scrolling reuses previously loaded parts');
    const sheetLifecycle=await liveSheets.split.evaluate(async()=>{
      const bdf=await import('/_build/js/debug/build/browser/browser.js'),manifest=new Uint8Array(await(await fetch('./split/manifest.json')).arrayBuffer());
      const load=async hash=>new Uint8Array(await(await fetch(`./split/parts/${hash}`)).arrayBuffer());
      const old=document.createElement('div');old.textContent='existing';old.style.cssText='width:400px;height:300px';document.body.append(old);
      let preserved=false;try{await bdf.mount_bdf_split_async(old,manifest,async()=>{throw new Error('failed')},'single')}catch{preserved=old.textContent==='existing'&&!old[Symbol.for('f4ah6o.bdf.sheet')]}
      const cancelled=document.createElement('div');cancelled.style.cssText='width:400px;height:300px';document.body.append(cancelled);
      let start,release;const started=new Promise(r=>start=r),gate=new Promise(r=>release=r);
      const pending=bdf.mount_bdf_split_async(cancelled,manifest,async hash=>{start();await gate;return load(hash)},'single');
      await started;bdf.unmount_bdf(cancelled);release();let rejected=false;try{await pending}catch{rejected=true}
      const cancelledClean=rejected&&cancelled.childElementCount===0&&!cancelled[Symbol.for('f4ah6o.bdf.sheet')];
      const concurrent=document.createElement('div');concurrent.style.cssText='width:400px;height:300px';document.body.append(concurrent);
      let slowStart,slowRelease;const slowStarted=new Promise(r=>slowStart=r),slowGate=new Promise(r=>slowRelease=r);
      const slow=bdf.mount_bdf_split_async(concurrent,manifest,async hash=>{slowStart();await slowGate;return load(hash)},'single');
      await slowStarted;await bdf.mount_bdf_split_async(concurrent,manifest,load,'single');const current=concurrent.querySelector('canvas');slowRelease();let oldRejected=false;try{await slow}catch{oldRejected=true}
      const newerSurvives=oldRejected&&concurrent.querySelector('canvas')===current&&!!concurrent[Symbol.for('f4ah6o.bdf.sheet')];
      const countFonts=()=>[...document.fonts].filter(face=>face.family.startsWith('bdf-')).length;
      const beforeFonts=countFonts(),originalClose=ImageBitmap.prototype.close;let closed=0;
      ImageBitmap.prototype.close=function(){closed++;return originalClose.call(this)};
      const resourceHost=document.createElement('div');resourceHost.style.cssText='width:400px;height:300px';document.body.append(resourceHost);
      let resourceLifetime=false;
      try{
        await bdf.mount_bdf_split_async(resourceHost,manifest,load,'single');const retained=countFonts()===beforeFonts+1;
        bdf.unmount_bdf(resourceHost);
        await new Promise((resolve,reject)=>{const timeout=setTimeout(()=>reject(new Error('sheet resources not released')),5000);const check=()=>{if(countFonts()===beforeFonts&&closed>0){clearTimeout(timeout);resolve()}else requestAnimationFrame(check)};check()});
        resourceLifetime=retained&&countFonts()===beforeFonts&&closed>0;
      }finally{ImageBitmap.prototype.close=originalClose;resourceHost.remove()}
      const scrolling=document.createElement('div');scrolling.style.cssText='width:400px;height:300px';document.body.append(scrolling);
      let blockedStart,blockedRelease;const blocked=new Promise(r=>blockedStart=r),blockedGate=new Promise(r=>blockedRelease=r),delayedHash=window.metadata.views[0].tiles['2,0'];
      await bdf.mount_bdf_split_async(scrolling,manifest,async hash=>{if(hash===delayedHash){blockedStart();await blockedGate}return load(hash)},'single');
      const canvas=scrolling.querySelector('canvas'),updates=[];const observer=new MutationObserver(()=>updates.push(canvas.dataset.bdfSheetViewport));observer.observe(canvas,{attributes:true,attributeFilter:['data-bdf-sheet-viewport']});
      scrolling.scrollLeft=200;await blocked;const before=Number(canvas.dataset.bdfSheetFrame);scrolling.scrollLeft=0;
      await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));blockedRelease();
      await new Promise((resolve,reject)=>{const timeout=setTimeout(()=>reject(new Error('sheet did not redraw')),5000);const check=()=>{if(Number(canvas.dataset.bdfSheetFrame)>before&&canvas.dataset.bdfSheetViewport===JSON.stringify([0,0,400,300])){clearTimeout(timeout);resolve()}else requestAnimationFrame(check)};check()});
      const staleDiscarded=updates.every(value=>JSON.parse(value)[0]===0);observer.disconnect();bdf.unmount_bdf(scrolling);
      bdf.unmount_bdf(concurrent);old.remove();cancelled.remove();concurrent.remove();scrolling.remove();
      return{preserved,cancelledClean,newerSurvives,staleDiscarded,resourceLifetime};
    });
    assert.deepEqual(sheetLifecycle,{preserved:true,cancelledClean:true,newerSurvives:true,staleDiscarded:true,resourceLifetime:true},'sheet failures, cancellation, scrolling and resource lifetime');
    const externalTileIndex=await liveSheets.split.evaluate(async()=>{
      const bdf=await import('/_build/js/debug/build/browser/browser.js'),metadata=structuredClone(window.metadata),view=metadata.views[0],indexHash='00000000000000000000000000000000';
      const entries=Object.entries(view.tiles).map(([key,hash])=>{const [x,y]=key.split(',').map(Number);return{x,y,hash}}).sort((a,b)=>a.y-b.y||a.x-b.x);
      const bytes=new Uint8Array(entries.length*24),data=new DataView(bytes.buffer);
      for(const [i,e] of entries.entries()){data.setUint32(i*24,e.x,true);data.setUint32(i*24+4,e.y,true);for(let j=0;j<16;j++)bytes[i*24+8+j]=parseInt(e.hash.slice(j*2,j*2+2),16)}
      delete view.tiles;view.tilesRef=indexHash;metadata.parts.push({h:indexHash,t:'idx',enc:'identity',len:bytes.length,size:bytes.length});
      const manifest=new TextEncoder().encode(JSON.stringify(metadata)),requests=[];
      const loader=async hash=>{requests.push(hash);return hash===indexHash?bytes:new Uint8Array(await(await fetch(`./split/parts/${hash}`)).arrayBuffer())};
      const host=document.createElement('div');host.style.cssText='width:400px;height:300px';document.body.append(host);
      const count=await bdf.render_bdf_sheet_region_split_async(host,manifest,loader,0,0,200,200,1);
      const regionLoads=requests.slice();requests.length=0;
      const mounted=await bdf.mount_bdf_split_async(host,manifest,loader,'single');
      const mountLoads=requests.slice(),rendered=!!host.querySelector('[data-bdf-sheet-frame]');bdf.unmount_bdf(host);host.remove();
      return{count,mounted,rendered,regionLoads,mountLoads,indexHash,first:entries[0].hash};
    });
    assert.equal(externalTileIndex.count,1,'external tile index selects the visible tile');
    assert.deepEqual(externalTileIndex.regionLoads,[externalTileIndex.indexHash,externalTileIndex.first],'external tile index does not load offscreen tiles');
    assert.equal(externalTileIndex.mounted,1,'sheet viewer opens an external tile index');
    assert.equal(externalTileIndex.rendered,true,'sheet viewer draws an external tile index');
    assert.equal(externalTileIndex.mountLoads.filter(hash=>hash===externalTileIndex.indexHash).length,1,'external tile index fetched once');
    const encryptedSheet=await liveSheets.moon.evaluate(async()=>{
      const bdf=await import('/_build/js/debug/build/browser/browser.js'),fetchBytes=async url=>new Uint8Array(await(await fetch(url)).arrayBuffer());
      const single=await fetchBytes('./encrypted.bdf'),manifest=await fetchBytes('./encrypted-split/manifest.json');
      const loader=async(hash,limit)=>{const bytes=await fetchBytes(`./encrypted-split/parts/${hash}`);if(bytes.length>limit)throw new Error('too large');return bytes};
      const host=document.createElement('div');host.style.cssText='width:400px;height:300px';document.body.append(host);
      await bdf.mount_bdf_encrypted_async(host,single,'pass','single');const one=host.querySelector('canvas').toDataURL();
      await bdf.mount_bdf_encrypted_split_async(host,manifest,loader,'pass','single');const split=host.querySelector('canvas').toDataURL();
      const existing=host.querySelector('canvas');let wrong=false;try{await bdf.mount_bdf_encrypted_async(host,single,'wrong','single')}catch{wrong=host.querySelector('canvas')===existing}
      bdf.unmount_bdf(host);host.remove();return{one,split,wrong};
    });
    const plain=PNG.sync.read(Buffer.from(sheetInitial.split(',')[1],'base64'));
    for(const [name,value] of [['single',encryptedSheet.one],['split',encryptedSheet.split]]){
      const actual=PNG.sync.read(Buffer.from(value.split(',')[1],'base64'));let changed=0;
      for(let i=0;i<plain.data.length;i+=4)if(plain.data[i]!==actual.data[i]||plain.data[i+1]!==actual.data[i+1]||plain.data[i+2]!==actual.data[i+2]||plain.data[i+3]!==actual.data[i+3])changed++;
      assert.ok(changed/(plain.width*plain.height)<=0.0005,`encrypted ${name} sheet differs in ${changed} pixels`);
    }
    assert.equal(encryptedSheet.wrong,true,'wrong sheet credentials preserve the mounted document');
    for(const page of Object.values(liveSheets))await page.close();
    const hiDPI={};
    for(const name of ['baseline','moon','split']){
      const page=await browser.newPage({viewport:{width:1280,height:720},deviceScaleFactor:2});
      await page.goto(`${sheetBase}live-${name}.html`,{waitUntil:'networkidle'});
      await page.waitForFunction(()=>window.bdfStatus==='ready'||window.bdfStatus==='error');
      assert.equal(await page.evaluate(()=>window.bdfStatus),'ready',`HiDPI ${name}: sheet render failed`);
      hiDPI[name]=await page.evaluate(()=>document.querySelector('canvas').toDataURL());await page.close();
    }
    const hdReference=PNG.sync.read(Buffer.from(hiDPI.baseline.split(',')[1],'base64'));
    for(const name of ['moon','split']){
      const actual=PNG.sync.read(Buffer.from(hiDPI[name].split(',')[1],'base64'));
      assert.deepEqual([actual.width,actual.height],[800,600],`HiDPI ${name}: canvas dimensions`);
      let changed=0;for(let i=0;i<hdReference.data.length;i+=4)if(hdReference.data[i]!==actual.data[i]||hdReference.data[i+1]!==actual.data[i+1]||hdReference.data[i+2]!==actual.data[i+2]||hdReference.data[i+3]!==actual.data[i+3])changed++;
      assert.ok(changed/(800*600)<=0.0005,`HiDPI ${name}: sheet differs in ${changed} pixels`);
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
  const sheetBase = `http://127.0.0.1:${server.address().port}/compat/sheet/`;
  const continuousBase = `http://127.0.0.1:${server.address().port}/compat/continuous/`;
  for(const [kind,name,width,height] of [['region','moon',200,200],['region','split',200,200],['region','encrypted',200,200],['region','encrypted-split',200,200],['viewer','moon',200,200],['spread','moon',376,120],['zoom','moon',376,120]]){
    const target=path.join(output,`continuous-${kind}-${name}`);mkdirSync(target);
    await run(['diff','html','--url',`${continuousBase}${kind}-baseline.html`,'--current-url',`${continuousBase}${kind}-${name}.html`,'--output-dir',target,'--no-paint-tree']);
    const reportPath=path.join(target,'diff-report.json'),report=JSON.parse(readFileSync(reportPath,'utf8'));
    for(const result of report.results){
      const reference=PNG.sync.read(readFileSync(path.join(target,`compat_continuous_${kind}-baseline-${result.viewport}.png`)));
      const actual=PNG.sync.read(readFileSync(path.join(target,`compat_continuous_${kind}-${name}-${result.viewport}.png`)));
      const area=Math.min(reference.width,width)*Math.min(reference.height,height);
      let changed=0;for(let i=0;i<reference.data.length;i+=4)if(reference.data[i]!==actual.data[i]||reference.data[i+1]!==actual.data[i+1]||reference.data[i+2]!==actual.data[i+2]||reference.data[i+3]!==actual.data[i+3])changed++;
      console.log(`continuous ${kind}-${name} ${result.viewport}: ${changed} pixels changed (${(changed/area*100).toFixed(4)}%)`);
      assert.ok(changed/area<=0.0005,`${kind}-${name} ${result.viewport}: continuous visual difference exceeds 0.05%`);
    }
    await run(['diff','agent',reportPath,'--no-history']);
  }
  {
    const musicBase=`http://127.0.0.1:${server.address().port}/compat/music/`,target=path.join(output,'piano');mkdirSync(target);
    await run(['diff','html','--url',`${musicBase}piano-baseline.html`,'--current-url',`${musicBase}piano-moon.html`,'--output-dir',target,'--no-paint-tree']);
    const reportPath=path.join(target,'diff-report.json'),report=JSON.parse(readFileSync(reportPath,'utf8'));
    assert.equal(report.results.length,3,'expected three piano viewports');
    for(const result of report.results){
      const a=PNG.sync.read(readFileSync(path.join(target,`compat_music_piano-baseline-${result.viewport}.png`))),b=PNG.sync.read(readFileSync(path.join(target,`compat_music_piano-moon-${result.viewport}.png`)));
      let changed=0;for(let i=0;i<a.data.length;i+=4)if(a.data[i]!==b.data[i]||a.data[i+1]!==b.data[i+1]||a.data[i+2]!==b.data[i+2]||a.data[i+3]!==b.data[i+3])changed++;
      assert.ok(changed/(a.width*Math.min(a.height,400))<=0.0005,`${result.viewport}: piano visual difference exceeds 0.05%`);
    }
    await run(['diff','agent',reportPath,'--no-history']);
  }
  await run(['scan','scroll',`${continuousBase}viewer-moon.html`,'--no-ledger']);
  await run(['check','scroll',`${continuousBase}viewer-moon.html`,'--no-ledger']);
  {
    const target=path.join(output,'sheet-zoom');mkdirSync(target);
    await run(['diff','html','--url',`${sheetBase}zoom-baseline.html`,'--current-url',`${sheetBase}zoom-moon.html`,'--output-dir',target,'--no-paint-tree']);
    const reportPath=path.join(target,'diff-report.json'),report=JSON.parse(readFileSync(reportPath,'utf8'));
    for(const result of report.results){
      const reference=PNG.sync.read(readFileSync(path.join(target,`compat_sheet_zoom-baseline-${result.viewport}.png`))),actual=PNG.sync.read(readFileSync(path.join(target,`compat_sheet_zoom-moon-${result.viewport}.png`)));
      let changed=0;for(let i=0;i<reference.data.length;i+=4)if(reference.data[i]!==actual.data[i]||reference.data[i+1]!==actual.data[i+1]||reference.data[i+2]!==actual.data[i+2]||reference.data[i+3]!==actual.data[i+3])changed++;
      const area=Math.min(reference.width,400)*Math.min(reference.height,300);console.log(`sheet zoom ${result.viewport}: ${changed} pixels changed (${(changed/area*100).toFixed(4)}%)`);assert.ok(changed/area<=0.0005,`${result.viewport}: sheet zoom visual difference exceeds 0.05%`);
    }
    await run(['diff','agent',reportPath,'--no-history']);
  }
  for(const name of ['moon','split']){
    const target=path.join(output,`sheet-${name}`);mkdirSync(target);
    await run(['diff','html','--url',`${sheetBase}baseline.html`,'--current-url',`${sheetBase}${name}.html`,'--output-dir',target,'--no-paint-tree']);
    const reportPath=path.join(target,'diff-report.json'),report=JSON.parse(readFileSync(reportPath,'utf8'));
    for(const result of report.results){
      const reference=PNG.sync.read(readFileSync(path.join(target,`compat_sheet_baseline-${result.viewport}.png`)));
      const actual=PNG.sync.read(readFileSync(path.join(target,`compat_sheet_${name}-${result.viewport}.png`)));
      let changed=0;for(let i=0;i<reference.data.length;i+=4)if(reference.data[i]!==actual.data[i]||reference.data[i+1]!==actual.data[i+1]||reference.data[i+2]!==actual.data[i+2]||reference.data[i+3]!==actual.data[i+3])changed++;
      const ratio=changed/(Math.min(reference.width,400)*Math.min(reference.height,300));
      console.log(`sheet ${name} ${result.viewport}: ${changed} pixels changed (${(ratio*100).toFixed(4)}%)`);
      assert.ok(ratio<=0.0005,`${name} ${result.viewport}: sheet visual difference exceeds 0.05%`);
    }
    await run(['diff','agent',reportPath,'--no-history']);
  }
  await run(['scan','scroll',`${sheetBase}live-moon.html`,'--no-ledger']);
  await run(['check','scroll',`${sheetBase}live-moon.html`,'--no-ledger']);
  const sheetFindOutput=path.join(output,'sheet-find');mkdirSync(sheetFindOutput);
  await run(['diff','html','--url',`${sheetBase}find-baseline.html`,'--current-url',`${sheetBase}find-moon.html`,'--output-dir',sheetFindOutput,'--no-paint-tree']);
  const sheetFindReport=path.join(sheetFindOutput,'diff-report.json'),sheetFind=JSON.parse(readFileSync(sheetFindReport,'utf8'));
  for(const result of sheetFind.results){
    const reference=PNG.sync.read(readFileSync(path.join(sheetFindOutput,`compat_sheet_find-baseline-${result.viewport}.png`)));
    const actual=PNG.sync.read(readFileSync(path.join(sheetFindOutput,`compat_sheet_find-moon-${result.viewport}.png`)));
    let changed=0;for(let i=0;i<reference.data.length;i+=4)if(reference.data[i]!==actual.data[i]||reference.data[i+1]!==actual.data[i+1]||reference.data[i+2]!==actual.data[i+2]||reference.data[i+3]!==actual.data[i+3])changed++;
    const ratio=changed/(Math.min(reference.width,400)*Math.min(reference.height,300));
    console.log(`sheet find ${result.viewport}: ${changed} pixels changed (${(ratio*100).toFixed(4)}%)`);
    assert.ok(ratio<=0.0005,`${result.viewport}: sheet search visual difference exceeds 0.05%`);
  }
  await run(['diff','agent',sheetFindReport,'--no-history']);
  await run(['scan','handlers',`${sheetBase}find-moon.html`,'--no-ledger']);
  await run(['check','interactions',`${sheetBase}find-moon.html`,'--reference',`${sheetBase}find-baseline.html`,'--handlers','--no-ledger']);
  const sheetCellOutput=path.join(output,'sheet-cells');mkdirSync(sheetCellOutput);
  await run(['diff','html','--url',`${sheetBase}cells-baseline.html`,'--current-url',`${sheetBase}cells-moon.html`,'--output-dir',sheetCellOutput,'--no-paint-tree']);
  const sheetCellReport=path.join(sheetCellOutput,'diff-report.json'),sheetCell=JSON.parse(readFileSync(sheetCellReport,'utf8'));
  for(const result of sheetCell.results){
    const reference=PNG.sync.read(readFileSync(path.join(sheetCellOutput,`compat_sheet_cells-baseline-${result.viewport}.png`)));
    const actual=PNG.sync.read(readFileSync(path.join(sheetCellOutput,`compat_sheet_cells-moon-${result.viewport}.png`)));
    let changed=0;for(let i=0;i<reference.data.length;i+=4)if(reference.data[i]!==actual.data[i]||reference.data[i+1]!==actual.data[i+1]||reference.data[i+2]!==actual.data[i+2]||reference.data[i+3]!==actual.data[i+3])changed++;
    const ratio=changed/(Math.min(reference.width,400)*Math.min(reference.height,300));
    console.log(`sheet cells ${result.viewport}: ${changed} pixels changed (${(ratio*100).toFixed(4)}%)`);
    assert.ok(ratio<=0.0005,`${result.viewport}: sheet cell selection visual difference exceeds 0.05%`);
  }
  await run(['diff','agent',sheetCellReport,'--no-history']);
  await run(['scan','handlers',`${sheetBase}cells-moon.html`,'--no-ledger']);
  await run(['check','interactions',`${sheetBase}cells-moon.html`,'--reference',`${sheetBase}cells-baseline.html`,'--handlers','--no-ledger']);
  for(const name of ['moon','split','interactive-moon']){
    const target=path.join(output,`sheet-live-${name}`);mkdirSync(target);
    await run(['diff','html','--url',`${sheetBase}live-baseline.html`,'--current-url',`${sheetBase}live-${name}.html`,'--output-dir',target,'--no-paint-tree']);
    const reportPath=path.join(target,'diff-report.json'),report=JSON.parse(readFileSync(reportPath,'utf8'));
    for(const result of report.results){
      const reference=PNG.sync.read(readFileSync(path.join(target,`compat_sheet_live-baseline-${result.viewport}.png`)));
      const actual=PNG.sync.read(readFileSync(path.join(target,`compat_sheet_live-${name}-${result.viewport}.png`)));
      let changed=0;for(let i=0;i<reference.data.length;i+=4)if(reference.data[i]!==actual.data[i]||reference.data[i+1]!==actual.data[i+1]||reference.data[i+2]!==actual.data[i+2]||reference.data[i+3]!==actual.data[i+3])changed++;
      const ratio=changed/(Math.min(reference.width,400)*Math.min(reference.height,300));
      console.log(`live sheet ${name} ${result.viewport}: ${changed} pixels changed (${(ratio*100).toFixed(4)}%)`);
      assert.ok(ratio<=0.0005,`${name} ${result.viewport}: live sheet visual difference exceeds 0.05%`);
    }
    await run(['diff','agent',reportPath,'--no-history']);
  }
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
    const pageLeft = Math.max(0, (baseline.width - 640) / 2);
    const sample = (80 * baseline.width + pageLeft + 40) * 4;
    assert.ok(baseline.data[sample + 2] > 100 && baseline.data[sample] < 100 && baseline.data[sample + 3] === 255, 'baseline capture is blank or incomplete');
    if (baseline.width > 540) {
      const svg = (280 * baseline.width + pageLeft + 510) * 4;
      assert.ok(baseline.data[svg] > 200 && baseline.data[svg + 1] > 150 && baseline.data[svg + 2] < 140, 'SVG was not rendered');
      let fontPixels = 0;
      for (let y = 340; y < 390; y++) for (let x = pageLeft + 385; x < pageLeft + 480; x++) {
        const i = (y * baseline.width + x) * 4;
        if (baseline.data[i] < 100 && baseline.data[i + 1] < 100 && baseline.data[i + 2] < 120) fontPixels++;
      }
      assert.ok(fontPixels > 200, 'embedded font was not rendered');
    }
    if (baseline.height > 510) {
      const group = (430 * baseline.width + pageLeft + 40) * 4;
      const alphaMask = (430 * baseline.width + pageLeft + 230) * 4;
      assert.ok(baseline.data[group] > 200 && baseline.data[group + 1] < 180, 'transparency group was not rendered');
      assert.ok(baseline.data[alphaMask + 1] > baseline.data[alphaMask] && baseline.data[alphaMask] < 200, 'alpha mask was not rendered');
      if (baseline.width > 520) {
        const luminosityMask = (430 * baseline.width + pageLeft + 400) * 4;
        const transparentMask = (430 * baseline.width + pageLeft + 480) * 4;
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
