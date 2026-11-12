// Real public AWS XML -> worker -> BDF, decoded independently.
import assert from 'node:assert/strict';
import {mkdtempSync, readFileSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {resolve, join} from 'node:path';
import {execFileSync} from 'node:child_process';
import {BdfDocument, BufferSource, decodeObject, NoopSink, walk} from '@bdfkit/core';
const root=resolve(import.meta.dirname,'../..'), dir=mkdtempSync(join(tmpdir(),'bdf-rounded-'));
const near=(a,b)=>assert.ok(Math.abs(a-b)<0.0001,`${a} != ${b}`);
try {
  writeFileSync(join(dir,'aws.drawio'),readFileSync(join(root,'site/samples/aws.drawio')));
  execFileSync(process.execPath,[join(root,'compat/drawio/oracle-worker.mjs')],{
    env:{...process.env,INPUT:join(dir,'aws.drawio'),OUTPUT:join(dir,'aws.bdf'),WORKER_TARGET:join(root,'_build/js/debug/build/native_converter_worker/native_converter_worker.js')},timeout:65000});
  const doc=await BdfDocument.open(new BufferSource(readFileSync(join(dir,'aws.bdf'))));
  const object=decodeObject(await doc.part(doc.manifest.views[0].pages[0].layers[0].obj));
  class Strokes extends NoopSink { paths=[]; strokePath(i){this.paths.push(object.paths[i].inline);} }
  const sink=new Strokes(); walk(object,sink);
  const strokes=sink.paths.slice(-8); assert.equal(strokes.length,8);
  // Source: upstream shape.addPoints, arcSize=20 / 2; coordinates in BDF
  // space (0.75 scale). These are Q-to-C equivalent controls, not splines.
  const expected=[
    [50,102.5,80,102.5,85,102.5,87.5,103.75,87.5,106.25,87.5,108.125,87.5,109.375,90,110,95,110,123.323,110],
    [170,110,228.323,110],
    [275,110,297.5,110,302.5,110,305,107.5,305,102.5,305,80,305,75,307.5,72.5,312.5,72.5,333.323,72.5],
    [275,110,297.5,110,302.5,110,305,112.5,305,117.5,305,132.5,305,137.5,307.5,140,312.5,140,333.323,140],
  ];
  for(let i=0;i<4;i++){
    const path=strokes[2*i];
    assert.equal(path.args.length,expected[i].length);
    [...path.args].forEach((v,k)=>near(v,expected[i][k]));
    assert.deepEqual([...path.verbs],i===1?[0,1]:[0,1,3,1,3,1]);
    assert.deepEqual([...strokes[2*i+1].verbs],[0,1,1]);
  }
  console.log('AWS Current all four connectors: equivalent cubic corners and shortened endpoints passed');
} finally {rmSync(dir,{recursive:true,force:true});}
