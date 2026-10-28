import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { BdfDocument, decodeObject, decodeTextIndex, extractContent, parseCellRef } from '@bdfkit/core';
import { tableCells, cellClipboard, hasExtent, runRect, PageRenderer } from '@bdfkit/render';

const dir = new URL('.', import.meta.url);
const grid=[];const gridContext={save(){},restore(){},beginPath(){},stroke(){},moveTo(x,y){grid.push([x,y])},lineTo(x,y){grid.at(-1).push(x,y)}};
Object.create(PageRenderer.prototype).drawGridlines(gridContext,{cols:[[1100,0.1]],rows:[[1,1]]},{x:100,y:0,w:2,h:1},1);
assert.equal(grid.filter(([x0,,x1])=>x0===x1).length,20);
const sampleRun = {text:'Hello world',x:30,y:50,advance:110,size:20,font:{kind:0,family:'serif',weight:400,style:0},align:0,matrix:[1,0,0,1,0,0],altText:false};
const measure = (_,text) => text.length * 5;
assert.deepEqual(runRect(sampleRun,1,5,measure), {x:40,y:34,w:40,h:20});
assert.deepEqual(runRect({...sampleRun,align:2,matrix:[0,1,-1,0,5,6]},1,5,measure), {x:26,y:5,w:20,h:40});
assert.deepEqual(runRect({...sampleRun,align:1,advance:0},1,5,measure), {x:-20,y:34,w:20,h:20});
assert.equal(hasExtent({...sampleRun,altText:true,advance:0}), false);
const indexBytes = Buffer.from('42545854010003000100020548656c6c6f0001010106e4b896e7958c02000302046e657874', 'hex');
const indexSource = readFileSync(new URL('../../core/text_index_test.mbt', dir), 'utf8');
const indexLiteral = indexSource.match(/b"(BTXT[^\"]+)"/);
assert.ok(indexLiteral, 'missing embedded BTXT fixture');
const embeddedIndex = Buffer.from(indexLiteral[1].replace(/\\x([0-9a-f]{2})/g, (_, hex) => String.fromCharCode(parseInt(hex, 16))), 'latin1');
assert.deepEqual(embeddedIndex, indexBytes);
assert.deepEqual(decodeTextIndex(indexBytes), [
  {a:0,b:1,ordinal:0,sep:2,text:'Hello'},
  {a:0,b:1,ordinal:1,sep:1,text:'世界'},
  {a:2,b:0,ordinal:3,sep:2,text:'next'},
]);
const parentBytes = readFileSync(new URL('parent.bobj', dir));
const childBytes = readFileSync(new URL('child.bobj', dir));
const testSource = readFileSync(new URL('../../render/text_test.mbt', dir), 'utf8');
for (const [name, expected] of [['parent', parentBytes], ['child', childBytes]]) {
  const match = testSource.match(new RegExp(`let ${name} = @core\\.decode_object_resources\\(\\s*b"([^"]+)"\\s*,?\\s*\\)`));
  assert.ok(match, `missing embedded ${name} fixture`);
  const embedded = Buffer.from([...match[1].matchAll(/\\x([0-9a-f]{2})/g)].map(m => parseInt(m[1], 16)));
  assert.deepEqual(embedded, expected, `embedded ${name} fixture differs`);
}
const parent = decodeObject(parentBytes);
const child = decodeObject(childBytes);
const hash = readFileSync(new URL('child.hash', dir), 'utf8');
const { runs, links } = extractContent(parent, h => h === hash ? child : undefined);
const fallbackIndex = [[0,0,runs], [0,1,extractContent(child).runs], [1,0,extractContent(child).runs]].flatMap(([a,b,rs]) => rs.map((r,i) => ({a,b,ordinal:r.ordinal,sep:i === 0 ? 2 : r.sep,text:r.text})));
const parentHash = '00000000000000000000000000000000';
const manifest = {bdf:1,parts:[{h:parentHash,t:'obj',len:parentBytes.length,size:parentBytes.length},{h:hash,t:'obj',len:childBytes.length,size:childBytes.length}],views:[{id:'v',kind:'fixed',pages:[{w:100,h:100,layers:[{role:'body',obj:parentHash},{role:'annotation',obj:hash}]},{w:100,h:100,layers:[{role:'body',obj:hash}]}]}]};
const doc = await BdfDocument.open({manifest:async()=>manifest,stored:async entry=>entry.h===parentHash ? parentBytes : childBytes});
assert.deepEqual(await doc.textIndex(manifest.views[0]), fallbackIndex);
const sheetManifest = {...manifest,views:[{id:'s',kind:'sheet',tile:50,tiles:{'2,0':hash,'0,1':parentHash,'1,0':parentHash}}]};
const sheetDoc = await BdfDocument.open({manifest:async()=>sheetManifest,stored:async entry=>entry.h===parentHash ? parentBytes : childBytes});
const sheetIndex = await sheetDoc.textIndex(sheetManifest.views[0]);
assert.deepEqual(sheetIndex.map(r=>r.text), ['Hello','World','second','wrapped','outlined','orphan','child','Hello','World','second','wrapped','outlined','orphan']);
assert.deepEqual(sheetIndex.map(r=>[r.a,r.b,r.ordinal,r.sep]), [[1,0,0,2],[1,0,1,1],[1,0,2,1],[1,0,3,0],[1,0,4,1],[1,0,7,1],[2,0,0,2],[0,1,0,2],[0,1,1,1],[0,1,2,1],[0,1,3,0],[0,1,4,1],[0,1,7,1]]);
assert.deepEqual(fallbackIndex.slice(-2), [
  {a:0,b:1,ordinal:0,sep:2,text:'child'},
  {a:1,b:0,ordinal:0,sep:2,text:'child'},
]);
assert.deepEqual(runs.map(r => r.text), ['Hello', 'World', 'second', 'wrapped', 'outlined', 'child', 'drawn by a child', 'orphan']);
assert.deepEqual(runs.map(r => r.sep), [2, 1, 1, 0, 1, 1, 1, 1]);
assert.deepEqual(runs.map(r => r.ordinal), [0, 1, 2, 3, 4, 5, 6, 7]);
assert.deepEqual([runs[4].x, runs[4].y, runs[4].altText, runs[4].lang], [5, 45, true, 'ja']);
assert.deepEqual([runs[5].x, runs[5].y, runs[5].advance, runs[5].matrix], [105, 107, 12, [1, 0, 0, 1, 100, 100]]);
assert.deepEqual([runs[6].x, runs[6].y, runs[6].advance, runs[6].altText], [52, 150, 20, true]);
assert.deepEqual([runs[7].x, runs[7].y, runs[7].altText], [0, 0, true]);
assert.deepEqual(links.map(({x, y, w, h, after, url}) => ({x, y, w, h, after, url})), [{x:14, y:31, w:4, h:3, after:6, url:'https://example.org/'}]);
const transformed = extractContent(parent, h => h === hash ? child : undefined, [2, 0, 0, 3, 4, 5]);
assert.deepEqual([transformed.runs[5].x, transformed.runs[5].y], [214, 326]);
assert.deepEqual([transformed.links[0].x, transformed.links[0].y, transformed.links[0].w, transformed.links[0].h], [32, 98, 8, 9]);
console.log('Upstream text extraction matches the MoonBit fixture expectations.');

const structureBytes = readFileSync(new URL('structure.bobj', dir));
const structureSource = readFileSync(new URL('../../render/structure_test.mbt', dir), 'utf8');
const embeddedStructure = structureSource.match(/let structure = @core\.decode_object_resources\(\s*b"([^"]+)"\s*,?\s*\)/);
assert.ok(embeddedStructure, 'missing embedded structure fixture');
assert.deepEqual(Buffer.from([...embeddedStructure[1].matchAll(/\\x([0-9a-f]{2})/g)].map(m => parseInt(m[1], 16))), structureBytes);
const structure = extractContent(decodeObject(structureBytes), h => h === hash ? child : undefined);
assert.deepEqual(structure.nodes.map(n => n.kind), ['heading','list','item','paragraph','list','item','paragraph','item','paragraph','table','caption','cell','paragraph','cell','paragraph','paragraph','figure','paragraph','cell','paragraph','paragraph','list','item','paragraph','figure','figure','paragraph','figure','figure','figure','figure','figure','heading','heading','heading']);
assert.deepEqual(structure.nodes.map(n => n.parent), [-1,-1,1,2,2,4,5,1,7,-1,9,9,11,9,13,-1,-1,16,-1,-1,-1,-1,21,22,-1,-1,25,-1,-1,-1,-1,30,-1,-1,-1]);
assert.deepEqual(structure.runs.map(r => r.node), [0,3,6,8,10,12,14,15,17,18,19,20,23,26,32,33,34]);
assert.equal(structure.nodes[0].level, 2);
assert.deepEqual([structure.nodes[32].level,structure.nodes[33].level,structure.nodes[34].level], [2,2,undefined]);
assert.deepEqual([structure.nodes[11].row,structure.nodes[11].col,structure.nodes[11].scope], [0,0,'col']);
assert.deepEqual([structure.nodes[13].row,structure.nodes[13].col,structure.nodes[13].rows,structure.nodes[13].cols], [0,1,1,2]);
assert.deepEqual([structure.nodes[18].row,structure.nodes[18].col], [11,1]);
assert.deepEqual([structure.nodes[19].quote,structure.nodes[20].code,structure.nodes[20].quote], [1,true,2]);
assert.deepEqual([structure.nodes[21].list,structure.nodes[21].quote], ['ordered',1]);
assert.deepEqual([structure.nodes[16].alt,structure.nodes[16].data], ['chart','chart-1']);
assert.deepEqual(structure.nodes[16].bounds, {x:0,y:160,w:30,h:62});
assert.deepEqual(structure.nodes[24].bounds, {x:15,y:302,w:10,h:10});
assert.deepEqual(structure.nodes[25].bounds, {x:52,y:292,w:20,h:21});
assert.deepEqual(structure.nodes[27].bounds, {x:33,y:44,w:0,h:0});
assert.deepEqual(structure.nodes[28].bounds, {x:200,y:100,w:10,h:10});
assert.deepEqual(structure.nodes[29].bounds, {x:0,y:0,w:0,h:0});
assert.deepEqual(structure.nodes[30].bounds, {x:11,y:12,w:13,h:14});
assert.deepEqual(structure.nodes[31].bounds, structure.nodes[30].bounds);
assert.deepEqual([structure.links[0].after,structure.links[0].node], [3,8]);
console.log('Upstream semantic structure matches the MoonBit fixture expectations.');

assert.deepEqual(parseCellRef('\ufeffZ10:A1\tcol\n'), {row:9,col:25,rows:1,cols:1,scope:'col'});
assert.equal(parseCellRef('A1\u0085'), undefined);

assert.deepEqual(tableCells(structure,9), [
  {row:0,col:0,rows:1,cols:1,text:'head',scope:'col'},
  {row:0,col:1,rows:1,cols:2,text:'wide'},
]);
assert.deepEqual(tableCells(structure), [{row:11,col:1,rows:1,cols:1,text:'セル'}]);
const cells=[{row:0,col:0,rows:1,cols:1,text:'head',scope:'col'},{row:0,col:1,rows:1,cols:2,text:'"wide"\n&<>'},{row:1,col:0,rows:2,cols:1,text:'a\tb'},{row:1,col:1,rows:1,cols:1,text:'42'}];
const clip=cellClipboard(cells,{row0:0,col0:0,row1:2,col1:2});
assert.equal(clip.text,'head\t"""wide""\n&<>"\t\n"a\tb"\t42\t\n\t\t');
assert.equal(clip.html,'<meta charset="utf-8"><table><tr><th scope="col">head</th><td colspan="2">&quot;wide&quot;<br style="mso-data-placement:same-cell">&amp;&lt;&gt;</td></tr><tr><td rowspan="2">a\tb</td><td>42</td><td></td></tr><tr><td></td><td></td></tr></table>');
const trimmed=cellClipboard(cells,{row0:0,col0:0,row1:4,col1:4},{trim:true});
assert.equal(trimmed.html,'<meta charset="utf-8"><table><tr><th scope="col">head</th><td>&quot;wide&quot;<br style="mso-data-placement:same-cell">&amp;&lt;&gt;</td></tr><tr><td>a\tb</td><td>42</td></tr></table>');
const hidden=cellClipboard(cells,{row0:0,col0:0,row1:2,col1:2},{skipRow:r=>r===1,skipCol:c=>c===1});
assert.equal(hidden.html,'<meta charset="utf-8"><table><tr><th scope="col">head</th><td>&quot;wide&quot;<br style="mso-data-placement:same-cell">&amp;&lt;&gt;</td></tr><tr><td>a\tb</td><td></td></tr></table>');
console.log('Upstream table cell collection and clipboard match the MoonBit fixture expectations.');

const cellsBytes=readFileSync(new URL('cells.bobj',dir));
const cellsSource=readFileSync(new URL('../../render/cells_extract_test.mbt',dir),'utf8');
const embeddedCells=cellsSource.match(/let object = @core\.decode_object_resources\(\s*b"([^"]+)"\s*,?\s*\)/);
assert.ok(embeddedCells,'missing embedded cells fixture');
assert.deepEqual(Buffer.from([...embeddedCells[1].matchAll(/\\x([0-9a-f]{2})/g)].map(m=>parseInt(m[1],16))),cellsBytes);
const nested=extractContent(decodeObject(cellsBytes),()=>undefined);
assert.deepEqual(tableCells(nested,0),[
 {row:0,col:0,rows:1,cols:1,text:'a b\nc duplicate'},
 {row:0,col:1,rows:1,cols:1,text:''},
 {row:0,col:2,rows:1,cols:1,text:'outer\ninner'},
]);
assert.deepEqual(tableCells(nested,9),[{row:0,col:0,rows:1,cols:1,text:'inner'}]);
assert.deepEqual(tableCells(nested),[{row:3,col:3,rows:1,cols:1,text:'sheet'}]);
