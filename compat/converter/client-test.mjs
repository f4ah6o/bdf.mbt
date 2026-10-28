import assert from 'node:assert/strict';
import { bdf_converter_client } from '../../_build/js/debug/build/browser/browser.js';
import { Converter } from '../../node_modules/@bdfkit/convert/dist/index.js';
class FakeWorker extends EventTarget {
  messages=[];terminated=false;
  postMessage(value){this.messages.push(structuredClone(value))}
  reply(value){this.dispatchEvent(new MessageEvent('message',{data:value}))}
  fail(message){const event=new Event('error');event.message=message;this.dispatchEvent(event)}
  terminate(){this.terminated=true}
}
async function exercise(kind){
 const worker=new FakeWorker(),client=kind==='upstream'?new Converter(worker,'/runtime.wasm'):bdf_converter_client(worker,'/runtime.wasm'),buffer=new Uint8Array([9,1,2,3,9]),pending=client.convert(buffer.subarray(1,4),{format:'csv',params:{play:'false'}});
 assert.deepEqual(worker.messages,[{type:'init',wasm:'/runtime.wasm'}]);worker.reply({id:0,ok:true,formats:[{name:'csv',description:'CSV',extensions:['csv']}]});const formats=await client.ready;await Promise.resolve();await Promise.resolve();
 const sent=worker.messages[1];assert.deepEqual([...new Uint8Array(sent.data)],[1,2,3]);assert.deepEqual([...buffer],[9,1,2,3,9]);assert.deepEqual(sent.options,{format:'csv',params:{play:'false'}});
 const page=client.page(17,2);await Promise.resolve();await Promise.resolve();const request=worker.messages[2];worker.reply({id:request.id,ok:true,result:{bdf:new Uint8Array([5]),warnings:[]}});worker.reply({id:sent.id,ok:true,result:{bdf:new Uint8Array([8]),format:'csv',summary:'ok',warnings:[],protected:false}});
 const [converted,convertedPage]=await Promise.all([pending,page]);const failed=client.finish(17);await Promise.resolve();await Promise.resolve();const failure=worker.messages.at(-1);worker.reply({id:failure.id,ok:false,error:'bad password',code:'wrong-password'});let error;try{await failed}catch(e){error={name:e.name,message:e.message,code:e.code}}
 const left=client.close(17);await Promise.resolve();await Promise.resolve();client.terminate();let termination;try{await left}catch(e){termination={name:e.name,message:e.message}}return {formats,converted,convertedPage,error,termination,terminated:worker.terminated};
}
assert.deepEqual(await exercise('moon'),await exercise('upstream'),'client message envelopes, ordering, errors and termination match upstream');
{
 const worker=new FakeWorker(),client=bdf_converter_client(worker,'/bad.wasm');worker.reply({id:0,ok:false,error:'startup failed',code:'bad-runtime'});await assert.rejects(client.ready,e=>e.name==='ConvertError'&&e.code==='bad-runtime');await assert.rejects(client.convert(new Uint8Array()),/startup failed/);client.terminate();
}
{
 const worker=new FakeWorker(),client=bdf_converter_client(worker,'/runtime.wasm');const ready=client.ready;client.terminate();await assert.rejects(ready,/converter terminated/);assert.equal(worker.terminated,true);
}
{
 const worker=new FakeWorker(),client=bdf_converter_client(worker,'/runtime.wasm');worker.reply({id:0,ok:true,formats:[]});await client.ready;const call=client.open(new Uint8Array([1]));await Promise.resolve();worker.fail('boom');await assert.rejects(call,/converter worker failed: boom/);await assert.rejects(client.convert(new Uint8Array()),/converter worker failed: boom/);client.terminate();
}
{
 const worker=new FakeWorker(),client=bdf_converter_client(worker,'/runtime.wasm');worker.reply({id:0,ok:true,formats:[]});await client.ready;const post=worker.postMessage.bind(worker);worker.postMessage=value=>{if(value.type==='convert')throw new Error('cannot clone');post(value)};
 await assert.rejects(client.convert(new Uint8Array([1])),/cannot clone/);const next=client.close(1);await Promise.resolve();worker.reply({id:worker.messages.at(-1).id,ok:true,result:null});assert.equal(await next,null);client.terminate();
}
console.log('Converter client compatibility: startup, concurrent calls, errors, buffer copies and termination match.');
