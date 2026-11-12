// Real public AWS XML -> BDF; independent upstream decoder checks cloud-icon bounds.
import assert from 'node:assert/strict';
import {mkdtempSync,readFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {resolve,join} from 'node:path';
import {execFileSync} from 'node:child_process';
import {BdfDocument,BufferSource,decodeObject} from '@bdfkit/core';
const root=resolve(import.meta.dirname,'../..');
const dir=mkdtempSync(join(tmpdir(),'bdf-stencil-arc-'));
try {
 const output=join(dir,'aws.bdf');
 execFileSync(process.execPath,[join(root,'compat/drawio/oracle-worker.mjs')],{
  env:{...process.env,INPUT:join(root,'site/samples/aws.drawio'),OUTPUT:output,
   WORKER_TARGET:join(root,'_build/js/debug/build/native_converter_worker/native_converter_worker.js')},timeout:65000});
 const doc=await BdfDocument.open(new BufferSource(readFileSync(output)));
 const obj=decodeObject(await doc.part(doc.manifest.views[0].pages[0].layers[0].obj));
 // Frame then its group_aws_cloud_alt stencil. Fail if fixture/order changes.
 const frame=obj.paths[0].inline, icon=obj.paths[1].inline;
 assert.deepEqual([...frame.verbs],[0,1,1,1,4]);
 assert.ok(icon.verbs.length>100,'complete cloud stencil, not a missing/simplified shape');
 const xmin=frame.args[0],ymin=frame.args[1];
 const size=25*.75;
 // All coordinates (including Bezier controls) belong to the 25-unit icon.
 // This checks the actual baked/path-transformed/encoded result, not helper math.
 for(let i=0;i<icon.args.length;i+=2){
  assert.ok(icon.args[i]>=xmin-0.001&&icon.args[i]<=xmin+size+0.001,`icon x escapes: ${icon.args[i]}`);
  assert.ok(icon.args[i+1]>=ymin-0.001&&icon.args[i+1]<=ymin+size+0.001,`icon y escapes: ${icon.args[i+1]}`);
 }
 console.log('AWS Cloud stencil arc integration: complete icon stays within its corner box');
} finally {rmSync(dir,{recursive:true,force:true});}
