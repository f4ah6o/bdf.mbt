import assert from 'node:assert/strict';

export async function verifyAudioBrowser(browser, visualBase) {
 const page=await browser.newPage();await page.goto(`${visualBase}moon.html`,{waitUntil:'networkidle'});
 const result=await page.evaluate(async()=>{
  const bdf=await import('/_build/js/debug/build/browser/browser.js'),{BdfDocument,BufferSource}=await import('@bdfkit/core'),{AudioPlayer}=await import('/node_modules/@bdfkit/render/dist/audio.js');
  const original=new Uint8Array(await(await fetch('/compat/music/fixtures/ode-mml.bdf')).arrayBuffer()),source=await BdfDocument.open(new BufferSource(original)),manifest=structuredClone(source.manifest),view=manifest.views[0],audioHash='1234567890abcdef1234567890abcdef';
  const wav=new Uint8Array(8044),w=new DataView(wav.buffer),write=(p,s)=>{for(let i=0;i<s.length;i++)wav[p+i]=s.charCodeAt(i)};
  write(0,'RIFF');w.setUint32(4,8036,true);write(8,'WAVE');write(12,'fmt ');w.setUint32(16,16,true);w.setUint16(20,1,true);w.setUint16(22,1,true);w.setUint32(24,8000,true);w.setUint32(28,8000,true);w.setUint16(32,1,true);w.setUint16(34,8,true);write(36,'data');w.setUint32(40,8000,true);for(let i=0;i<8000;i++)wav[44+i]=128+Math.round(48*Math.sin(2*Math.PI*440*i/8000));
  const header=new DataView(original.buffer,original.byteOffset,original.byteLength),oldStart=Number(header.getBigUint64(8,true)+header.getBigUint64(16,true)),oldParts=original.slice(oldStart);
  view.play={...view.play,audio:audioHash,type:'audio/wav'};manifest.parts.push({h:audioHash,t:'audio',enc:'identity',off:oldParts.length,len:wav.length,size:wav.length});
  const metadata=new TextEncoder().encode(JSON.stringify(manifest)),single=new Uint8Array(32+metadata.length+oldParts.length+wav.length);single.set(original.slice(0,32));const h=new DataView(single.buffer);h.setBigUint64(8,32n,true);h.setBigUint64(16,BigInt(metadata.length),true);h.setUint8(24,0);single.set(metadata,32);single.set(oldParts,32+metadata.length);single.set(wav,32+metadata.length+oldParts.length);
  const reference=await BdfDocument.open(new BufferSource(single)),data=await reference.audio(reference.manifest.views[0]),refEl=document.createElement('audio'),ref=new AudioPlayer(data.data,data.type,data.cues,{element:refEl});
  const waitMetadata=el=>new Promise((resolve,reject)=>{if(Number.isFinite(el.duration))return resolve();const timer=setTimeout(()=>reject(new Error('audio metadata timeout')),5000);el.addEventListener('loadedmetadata',()=>{clearTimeout(timer);resolve()},{once:true});el.addEventListener('error',()=>{clearTimeout(timer);reject(new Error('audio decode failed'))},{once:true})});
  const hosts=[],out=[];
  for(const kind of ['single','split']){
    const host=document.createElement('div');host.style.cssText='width:520px;height:400px';document.body.append(host);hosts.push(host);let requests=[];
    const loader=async(hash,max)=>{requests.push(hash);const part=manifest.parts.find(p=>p.h===hash),all=new Uint8Array(oldParts.length+wav.length);all.set(oldParts);all.set(wav,oldParts.length);if(max!==part.len)throw new Error('bad size limit');return all.slice(part.off,part.off+part.len)};
    if(kind==='single')await bdf.mount_bdf_async(host,single,'single');else await bdf.mount_bdf_split_async(host,metadata,loader,'single');
    const lazy=!requests.includes(audioHash)&&!requests.includes(view.play.cues),element=document.createElement('audio');element.muted=true;
    let invalid=false,invalidError;try{await Promise.race([bdf.bdf_audio_player_for_view_async(host,{}),new Promise((_,reject)=>setTimeout(()=>reject(new Error('invalid element timed out')),3000))])}catch(error){invalidError=String(error);invalid=/invalid audio element/.test(invalidError)}if(!invalid)throw new Error('invalid audio element did not reject: '+invalidError);
    const [player,second]=await Promise.all([bdf.bdf_audio_player_for_view_async(host,element),bdf.bdf_audio_player_for_view_async(host,document.createElement('audio'))]);second.dispose();
    const url=element.src,response=await fetch(url),type=response.headers.get('content-type'),context=new OfflineAudioContext(1,8000,8000),decoded=await context.decodeAudioData(await response.arrayBuffer()),signal=decoded.getChannelData(0).some(sample=>Math.abs(sample)>0.1);await waitMetadata(element);await player.play();await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(new Error('audio did not advance')),3000);const check=()=>{if(player.position>0){clearTimeout(timer);resolve()}else requestAnimationFrame(check)};check()});const advanced=player.position>0;player.pause();player.seek(0.4);
    const cursor=player.cursorAt(0.4),expectedCursor=ref.cursorAt(0.4),time=player.timeAt(0),expectedTime=ref.timeAt(0),duration=player.duration,state=player.state;
    bdf.unmount_bdf(host);let revoked=false;try{await fetch(url)}catch{revoked=true}
    out.push({kind,lazy,loads:requests.filter(x=>x===audioHash).length,cueLoads:requests.filter(x=>x===view.play.cues).length,type,duration,state,advanced,signal,cursor,expectedCursor,time,expectedTime,revoked,src:element.getAttribute('src')});host.remove();
  }
  ref.dispose();
  const sheetBytes=new Uint8Array(await(await fetch('/compat/sheet/cells.bdf')).arrayBuffer()),sheetDoc=await BdfDocument.open(new BufferSource(sheetBytes)),sheet=structuredClone(sheetDoc.manifest),sheetHeader=new DataView(sheetBytes.buffer,sheetBytes.byteOffset,sheetBytes.byteLength),sheetStart=Number(sheetHeader.getBigUint64(8,true)+sheetHeader.getBigUint64(16,true)),sheetParts=sheetBytes.slice(sheetStart);
  sheet.views[0].play={audio:audioHash,type:'audio/wav'};sheet.parts.push({h:audioHash,t:'audio',enc:'identity',off:sheetParts.length,len:wav.length,size:wav.length});
  const sheetMetadata=new TextEncoder().encode(JSON.stringify(sheet)),sheetSingle=new Uint8Array(32+sheetMetadata.length+sheetParts.length+wav.length),sh=new DataView(sheetSingle.buffer);sheetSingle.set(sheetBytes.slice(0,32));sh.setBigUint64(8,32n,true);sh.setBigUint64(16,BigInt(sheetMetadata.length),true);sh.setUint8(24,0);sheetSingle.set(sheetMetadata,32);sheetSingle.set(sheetParts,32+sheetMetadata.length);sheetSingle.set(wav,32+sheetMetadata.length+sheetParts.length);
  for(const kind of ['sheet-single','sheet-split']){
    const host=document.createElement('div');host.style.cssText='width:320px;height:220px';document.body.append(host);let fetched=0;
    const loader=async hash=>{const p=sheet.parts.find(p=>p.h===hash);if(hash===audioHash)fetched++;return hash===audioHash?wav:sheetParts.slice(p.off,p.off+p.len)};
    if(kind==='sheet-single')await bdf.mount_bdf_async(host,sheetSingle,'single');else await bdf.mount_bdf_split_async(host,sheetMetadata,loader,'single');
    const lazy=fetched===0,el=document.createElement('audio'),player=await bdf.bdf_audio_player_for_view_async(host,el),url=el.src;await waitMetadata(el);const duration=player.duration;bdf.unmount_bdf(host);let revoked=false;try{await fetch(url)}catch{revoked=true}out.push({kind,lazy,duration,revoked,loads:fetched});host.remove();
  }
  {
    const plain=new Uint8Array(await(await fetch('/compat/visual/fixture.bdf')).arrayBuffer()),host=document.createElement('div');host.style.cssText='width:500px;height:400px';document.body.append(host);await bdf.mount_bdf_async(host,plain,'single');const missing=await bdf.bdf_audio_player_for_view_async(host,null);bdf.unmount_bdf(host);host.remove();if(missing!==null)throw new Error('view without recording returned a player');
  }
  {
    const host=document.createElement('div');host.style.cssText='width:520px;height:400px';document.body.append(host);let release,started;const gate=new Promise(r=>release=r),entered=new Promise(r=>started=r);
    const loader=async hash=>{const p=manifest.parts.find(p=>p.h===hash);if(hash===audioHash){started();await gate;return wav}return oldParts.slice(p.off,p.off+p.len)};
    await bdf.mount_bdf_split_async(host,metadata,loader,'single');const element=document.createElement('audio'),created=[],originalCreate=URL.createObjectURL;URL.createObjectURL=function(blob){const url=originalCreate.call(this,blob);created.push(url);return url};
    try{const pending=bdf.bdf_audio_player_for_view_async(host,element);await entered;bdf.unmount_bdf(host);release();let rejected=false;try{await pending}catch{rejected=true}let revoked=false;try{await fetch(created[0])}catch{revoked=true}if(!rejected||!revoked||element.hasAttribute('src'))throw new Error('unmounted pending audio leaked a player')}finally{URL.createObjectURL=originalCreate;host.remove()}
  }
  {
    const host=document.createElement('div');host.style.cssText='width:520px;height:400px';document.body.append(host);let release,started,block=false,cueLoads=0;const gate=new Promise(r=>release=r),entered=new Promise(r=>started=r);const loader=async hash=>{const p=manifest.parts.find(p=>p.h===hash);if(hash===view.play.cues){cueLoads++;if(block){started();await gate}}return hash===audioHash?wav:oldParts.slice(p.off,p.off+p.len)};
    await bdf.mount_bdf_split_async(host,metadata,loader,'single');block=true;const recording=bdf.bdf_audio_player_for_view_async(host,document.createElement('audio')),midi=bdf.bdf_music_player_for_view_async(host,null);await entered;await new Promise(r=>setTimeout(r,20));release();const [a,m]=await Promise.all([recording,midi]);if(cueLoads!==1)throw new Error(`concurrent audio and MIDI fetched cues ${cueLoads} times`);a.dispose();m.dispose();bdf.unmount_bdf(host);host.remove();
  }
  return out;
 });
 for(const item of result){assert.ok(item.lazy&&item.revoked,`${item.kind}: lazy load and disposal: ${JSON.stringify(item)}`);assert.equal(item.duration,1);if(item.kind.startsWith('sheet-')){if(item.kind==='sheet-split')assert.equal(item.loads,1,'sheet audio is fetched on demand');continue}assert.ok(item.advanced&&item.signal,`${item.kind}: decoded audio contains a signal and advances`);assert.equal(item.type,'audio/wav');assert.equal(item.state,'paused');assert.equal(item.src,null);assert.deepEqual(item.cursor,item.expectedCursor);assert.equal(item.time,item.expectedTime);if(item.kind==='split'){assert.equal(item.loads,1,'concurrent players share audio part');assert.equal(item.cueLoads,1,'concurrent players share cue part')}}
 await page.close();
}
