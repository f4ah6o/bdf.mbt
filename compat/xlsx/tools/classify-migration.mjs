// Diagnostic only: never changes fixture content or relaxes the migration gate.
import { readFile, writeFile } from 'node:fs/promises';
import { parseArgs } from 'node:util';
import { loadFixture } from '../fixtures.mjs';
const {values}=parseArgs({options:{comparison:{type:'string'},report:{type:'string'}}});
if(!values.comparison||!values.report)throw Error('--comparison and --report required');
const source=JSON.parse(await readFile(values.comparison,'utf8'));
if(source.version!==1||!Array.isArray(source.differences)||!Array.isArray(source.missing))throw Error('Expected version 1 migration report');
const missing=[];
for(const file of source.missing){
 if(!/^[\w/-]+\.json$/.test(file)||file.split('/').includes('..'))throw Error('Invalid fixture name');
 const cases=await loadFixture('./'+file);
 const inputOnly=Array.isArray(cases)&&cases.length>0&&cases.every(c=>typeof c==='string'||(c&&typeof c==='object'&&!Array.isArray(c)&&typeof c.input==='string'&&Object.keys(c).every(k=>['label','input','mode','no_index','variant'].includes(k))));
 missing.push({file,count:Array.isArray(cases)?cases.length:null,classification:inputOnly?'retained-input-candidate':'unclassified',action:'Preserve; establish explicit seed inventory before changing generator or gate'});
}
const differences=source.differences.map(d=>{const keys=[...new Set(d.changes.flatMap(c=>c.keys))].sort();return {file:d.file,cases:d.changes.length,keys,classification:(!keys.length||d.previousCount!==d.generatedCount)?'structural-drift':keys.includes('input')?'input-generation-drift':keys.includes('value')?'case-data-drift':keys.every(k=>k==='bdf')?'encoded-output-drift':'expected-value-drift'};});
const result={version:1,diagnosticOnly:true,missing,differences,extra:source.extra,failures:source.failures,counts:{failures:source.failures.length,missing:missing.length,inputCandidates:missing.filter(x=>x.classification==='retained-input-candidate').length,differences:differences.length,extra:source.extra.length}};
await writeFile(values.report,JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result.counts));
