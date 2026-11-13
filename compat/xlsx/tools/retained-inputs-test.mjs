import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {mkdir,mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';import path from 'node:path';
import {validateRetained,exportRetained} from './retained-inputs.mjs';
const value=[{input:'AA==',mode:'x'}],entry={file:'x.json',kind:'input',sha256:createHash('sha256').update(JSON.stringify(value)).digest('hex')};
assert.ok(validateRetained(entry,value));
for(const key of ['bdf','want','expected'])assert.throws(()=>validateRetained(entry,[{...value[0],[key]:'expected'}]));
assert.throws(()=>validateRetained({...entry,sha256:'0'.repeat(64)},value));
assert.throws(()=>validateRetained({...entry,file:'../x.json'},value));
const out=await mkdtemp(path.join(tmpdir(),'bdf-retained-test-'));
try{await mkdir(path.join(out,'compat/xlsx'),{recursive:true});const receipts=await exportRetained(out);assert.equal(Object.keys(receipts).length,26);await assert.rejects(exportRetained(out),{code:'EEXIST'});console.log('26 retained inputs, integrity/schema/overwrite checks PASS');}finally{await rm(out,{recursive:true,force:true});}
