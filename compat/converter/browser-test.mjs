import assert from 'node:assert/strict';

export async function verifyConverterBrowser(browser, visualBase) {
 const page=await browser.newPage();await page.goto(`${visualBase}moon.html`,{waitUntil:'networkidle'});
 const result=await page.evaluate(async()=>{
  const {bdf_converter_client,bdf_create_converter}=await import('/_build/js/debug/build/browser/browser.js'),{Converter}=await import('/node_modules/@bdfkit/convert/dist/index.js'),{BdfDocument,BufferSource}=await import('@bdfkit/core');
  const pdf=()=>{const content=['BT /F1 18 Tf 20 70 Td (First page) Tj ET\n','BT /F1 18 Tf 20 70 Td (Second page) Tj ET\n'],objects=['<< /Type /Catalog /Pages 2 0 R >>','<< /Type /Pages /Kids [3 0 R 5 0 R] /Count 2 >>','<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 120] /Resources << /Font << /F1 7 0 R >> >> /Contents 4 0 R >>',`<< /Length ${content[0].length} >>\nstream\n${content[0]}endstream`,'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 220 140] /Resources << /Font << /F1 7 0 R >> >> /Contents 6 0 R >>',`<< /Length ${content[1].length} >>\nstream\n${content[1]}endstream`,'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'];let text='%PDF-1.4\n',offsets=[0];for(let i=0;i<objects.length;i++){offsets.push(text.length);text+=`${i+1} 0 obj\n${objects[i]}\nendobj\n`}const start=text.length;text+=`xref\n0 ${objects.length+1}\n0000000000 65535 f \n`;for(const offset of offsets.slice(1))text+=`${String(offset).padStart(10,'0')} 00000 n \n`;text+=`trailer\n<< /Size ${objects.length+1} /Root 1 0 R >>\nstartxref\n${start}\n%%EOF\n`;return new TextEncoder().encode(text)};
  const input=pdf(),wasm='/node_modules/@bdfkit/convert-office/dist/converter.wasm',out=[];
  for(const [kind,clientKind,workerKind] of [['upstream','upstream','upstream'],['moon-client','moon','upstream'],['moon-worker','upstream','moon'],['moon','moon','moon']]){
    const url=workerKind==='upstream'?'/node_modules/@bdfkit/convert/dist/worker.js':`/_build/js/debug/build/converter_worker/converter_worker.js?runtime=${encodeURIComponent('/node_modules/@bdfkit/convert/dist/worker.js')}`;
    const converter=kind==='moon'?bdf_create_converter(url,wasm):clientKind==='upstream'?new Converter(new Worker(url,{type:'module'}),wasm):bdf_converter_client(new Worker(url,{type:'module'}),wasm);
    try{
      const formats=await converter.ready,wrapped=new Uint8Array(input.length+8);wrapped.set(input,4);const source=wrapped.subarray(4,4+input.length);
      const converted=await converter.convert(source,{name:'two.pdf'}),opened=await converter.open(source,{name:'two.pdf'}),pages=[];
      if(!opened.stream||opened.pages!==2)throw new Error(`${kind}: expected two streamed PDF pages`);
      for(let i=0;i<2;i++){const item=await converter.page(opened.stream,i),doc=await BdfDocument.open(new BufferSource(item.bdf));pages.push({bdf:[...item.bdf],warnings:item.warnings,views:doc.manifest.views.map(v=>({kind:v.kind,pages:v.pages?.map(p=>[p.w,p.h])}))})}
      const finished=await converter.finish(opened.stream),closed=await converter.close(opened.stream),closedAgain=await converter.close(opened.stream);let missing;try{await converter.page(opened.stream,0)}catch(e){missing={name:e.name,message:e.message,code:e.code}}
      let unknown;try{await converter.convert(new Uint8Array([1,2,3]),{name:'bad.unknown'})}catch(e){unknown={name:e.name,message:e.message,code:e.code}}
      const csv=new TextEncoder().encode('name,value\nAlpha,42\nBeta,7\n'),csvResult=await converter.convert(csv,{name:'data.csv'}),csvOpen=await converter.open(csv,{name:'data.csv'}),csvDoc=await BdfDocument.open(new BufferSource(csvResult.bdf));
      const selected=await converter.convert(source,{name:'two.pdf',pages:'2'}),selectedDoc=await BdfDocument.open(new BufferSource(selected.bdf));
      const doc=await BdfDocument.open(new BufferSource(converted.bdf));out.push({kind,formats,converted:{...converted,bdf:[...converted.bdf]},opened:{...opened,bdf:[...opened.bdf]},finished:{...finished,bdf:[...finished.bdf]},closed,closedAgain,missing,unknown,pages,csvResult:{...csvResult,bdf:[...csvResult.bdf]},csvOpen:{...csvOpen,bdf:[...csvOpen.bdf]},csvKinds:csvDoc.manifest.views.map(v=>v.kind),selected:{...selected,bdf:[...selected.bdf]},selectedGeometry:selectedDoc.manifest.views[0].pages.map(p=>[p.w,p.h]),geometry:doc.manifest.views.map(v=>({kind:v.kind,pages:v.pages?.map(p=>[p.w,p.h])})),inputIntact:source.length===input.length&&source.every((v,i)=>v===input[i])});
    }finally{converter.terminate()}
  }
  {
    const converter=bdf_create_converter('/_build/js/debug/build/converter_worker/converter_worker.js',wasm);let failure;try{await Promise.race([converter.ready,new Promise((_,reject)=>setTimeout(()=>reject(new Error('worker startup timed out')),5000))])}catch(e){failure={name:e.name,message:e.message}}finally{converter.terminate()}if(failure?.name!=='ConvertError'||!failure.message.includes('requires a runtime URL'))throw new Error(`missing runtime failure: ${JSON.stringify(failure)}`);
  }
  {
    const failures=[];for(const kind of ['upstream','moon']){const url=kind==='upstream'?'/node_modules/@bdfkit/convert/dist/worker.js':`/_build/js/debug/build/converter_worker/converter_worker.js?runtime=${encodeURIComponent('/node_modules/@bdfkit/convert/dist/worker.js')}`,worker=new Worker(url,{type:'module'}),converter=kind==='upstream'?new Converter(worker,'/compat/converter/missing.wasm'):bdf_converter_client(worker,'/compat/converter/missing.wasm');try{await converter.ready}catch(e){failures.push({name:e.name,message:e.message,code:e.code})}finally{converter.terminate()}}if(JSON.stringify(failures[0])!==JSON.stringify(failures[1])||failures[1]?.message!=='wasm fetch failed: 404')throw new Error(`Wasm load failures differ: ${JSON.stringify(failures)}`);
  }
  return out;
 });
 const [expected,...variants]=result;delete expected.kind;for(const actual of variants){const name=actual.kind;delete actual.kind;assert.deepEqual(actual,expected,`${name}: actual TinyGo PDF conversion and streamed pages match upstream`);assert.ok(actual.inputIntact,'conversion leaves caller input intact');assert.equal(actual.pages.length,2);assert.equal(actual.closed,null);assert.equal(actual.closedAgain,null);assert.equal(actual.csvOpen.pages,0);assert.equal(actual.csvOpen.stream,undefined);assert.ok(actual.csvKinds.includes('sheet'));assert.deepEqual(actual.selectedGeometry,[[220,140]]);assert.equal(actual.missing.name,'ConvertError');assert.equal(actual.unknown.code,'unknown-format')}
 await page.close();
}
