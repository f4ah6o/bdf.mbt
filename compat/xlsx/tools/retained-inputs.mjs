import {createHash} from 'node:crypto';
import {readFile,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {loadFixture} from '../fixtures.mjs';
export function validateRetained(entry,value){
 if(!/^[\w-]+\.json$/.test(entry.file)||!['input','media'].includes(entry.kind))throw Error('Invalid retained input entry');
 if(!Array.isArray(value)||!value.length)throw Error('Empty or non-array retained input');
 const allowed=entry.kind==='media'?['label','index','mime','width','height','media']:['label','input','mode','no_index','variant'];
 for(const row of value){
  if(entry.kind==='input'&&typeof row==='string')continue;
  const field=entry.kind==='media'?'media':'input';
  if(!row||typeof row!=='object'||Array.isArray(row)||typeof row[field]!=='string'||Object.keys(row).some(k=>!allowed.includes(k)))throw Error('Retained corpus contains unknown/expected-output fields');
 }
 const content=JSON.stringify(value),hash=createHash('sha256').update(content).digest('hex');
 if(hash!==entry.sha256)throw Error('Retained input hash mismatch');
 return content;
}
export async function exportRetained(output){
 const manifest=JSON.parse(await readFile(new URL('./retained-inputs.manifest',import.meta.url),'utf8'));
 const receipts={};
 for(const entry of manifest){
  if(Object.hasOwn(receipts,entry.file))throw Error('Duplicate retained input');
  const content=validateRetained(entry,await loadFixture('./'+entry.file));
  await writeFile(path.join(output,'compat/xlsx',entry.file),content,{flag:'wx'});
  receipts[entry.file]=entry.sha256;
 }
 return receipts;
}
