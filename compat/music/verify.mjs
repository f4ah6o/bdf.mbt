import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { BdfDocument, BufferSource, parseSmf, decodeCues, tickToSeconds, secondsToTick } from '@bdfkit/core';
import { cursorAtTick, tickAt, lineAtTime, timeOfLine } from '@bdfkit/render';
import { eventAt, due, soundingEnds } from '../../node_modules/@bdfkit/render/dist/player.js';
import { inspect_smf, inspect_cues, inspect_times, inspect_cue_position, inspect_document_music } from '../../_build/js/debug/build/compat/music/music.js';

const u16=n=>[(n>>>8)&255,n&255],u32=n=>[(n>>>24)&255,(n>>>16)&255,(n>>>8)&255,n&255];
const vlq=n=>{const a=[n&127];while((n=Math.floor(n/128))>0)a.unshift((n&127)|128);return a};
const ev=(delta,...data)=>[...vlq(delta),...data],chunk=(id,data)=>[...Buffer.from(id),...u32(data.length),...data];
const smf=(format,division,tracks)=>new Uint8Array([...chunk('MThd',[...u16(format),...u16(tracks.length),...u16(division)]),...tracks.flatMap(t=>chunk('MTrk',t.flat()))]);
const eot=ev(0,255,47,0),tempo=(d,n)=>ev(d,255,81,3,n>>>16,(n>>>8)&255,n&255);
const fixtures=[
  smf(0,480,[[ev(0,192,5),ev(0,144,60,100),ev(0,64,90),ev(480,60,0),ev(0,128,64,0),ev(240,145,67,80),ev(240,129,67,0),eot]]),
  smf(1,96,[[tempo(0,1000000),tempo(96,250000),ev(0,255,88,4,3,3,24,8),ev(0,255,89,2,253,1),eot],[ev(0,144,60,64),ev(192,128,60,64),eot]]),
  smf(0,480,[[ev(0,144,60,100),ev(0,145,62,100),ev(480,177,123,0),ev(480,255,47,0)]]),
  smf(2,480,[[ev(0,144,60,1),ev(480,128,60,0),eot],[ev(0,144,62,1),ev(480,128,62,0),eot]]),
  smf(0,0xe728,[[tempo(0,1000000),ev(0,144,60,1),ev(500,128,60,0),eot]]),
  smf(0,480,[[ev(0,240,5,126,127,9,1,247),ev(0,255,3,4,72,111,114,110),ev(0,247,2,1,2),ev(0,144,72,50),ev(0,255,1,0),ev(10,72,0),eot]]),
  smf(0,100,[[...Array.from({length:80},(_,i)=>ev(i===0?0:1,144,60,1+i%126)),...Array.from({length:80},()=>ev(1,128,60,0)),eot]]),
  smf(1,480,[[tempo(0,1000000),tempo(0,2000000),ev(100,176,64,127),ev(400,176,64,0),eot],[ev(0,144,50,90),ev(480,128,50,0),ev(0,177,120,0),eot]]),
  new Uint8Array([...chunk('MThd',[0,1,0,2,0,96]),...chunk('XFIH',[1,2,3]),...chunk('MTrk',[...ev(0,144,60,1),...ev(0,255,1,143,255,255,127)])]),
  new Uint8Array([...chunk('MThd',[0,0,0,1,0,96]),...Buffer.from('MTrk'),255,255,255,255,...ev(0,144,60,1)]),
];
let seed=0x71e2c045;const random=n=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed%n};
for(let trial=0;trial<250;trial++){
  const tracks=[];for(let t=0;t<1+random(3);t++){
    const data=[];let status=0;
    for(let i=0;i<10+random(35);i++){
      const delta=random(320),ch=random(4),kind=random(9),key=48+random(36),value=random(128);
      if(kind<3){const next=(kind===0?128:144)|ch,bytes=[key,kind===2?0:value];if(next===status&&random(2))data.push(ev(delta,...bytes));else{data.push(ev(delta,next,...bytes));status=next}}
      else if(kind===3){status=176|ch;data.push(ev(delta,status,[7,64,120,121,123][random(5)],value))}
      else if(kind===4){status=192|ch;data.push(ev(delta,status,value))}
      else if(kind===5){status=224|ch;data.push(ev(delta,status,value,random(128)))}
      else if(kind===6)data.push(tempo(delta,100000+random(1900000)));
      else if(kind===7)data.push(ev(delta,255,88,2,1+random(12),random(8)));
      else data.push(ev(delta,255,89,2,random(15)-7&255,random(2)));
    }data.push(eot);tracks.push(data);
  }
  const divisions=[96,480,960,0xe728,0xe350];const data=smf(random(3),divisions[random(divisions.length)],tracks);fixtures.push(data);
  if(trial<100)fixtures.push(data.subarray(0,14+random(data.length-13)));
}
for(const [i,data] of fixtures.entries()){
  const expected=parseSmf(data),actual=JSON.parse(inspect_smf(data));assert.deepEqual(actual,expected,`SMF fixture ${i}`);
  for(const tick of [0,expected.ticks/3,expected.ticks,expected.ticks+137.5]){
    const seconds=tickToSeconds(expected,tick),result=JSON.parse(inspect_times(data,tick,seconds));
    assert.ok(Math.abs(result.seconds-seconds)<1e-9,`SMF ${i}: tick to time`);assert.ok(Math.abs(result.tick-secondsToTick(expected,seconds))<1e-8,`SMF ${i}: time to tick`);
    assert.equal(result.at,eventAt(expected.events,seconds));assert.equal(result.due,due(expected.events,0,seconds));assert.deepEqual(result.ends,[...soundingEnds(expected.events,expected.duration)]);
  }
}
for(const data of [new Uint8Array(20),new Uint8Array(chunk('MThd',[0,0,0,1])),smf(0,0,[[eot]])]){
  assert.throws(()=>parseSmf(data));assert.throws(()=>inspect_smf(data));
}

const varuint=n=>{n=BigInt(n);const out=[];do{let b=Number(n&127n);n>>=7n;if(n)b|=128;out.push(b)}while(n);return out};
const f32=n=>{const b=Buffer.alloc(4);b.writeFloatLE(n);return [...b]};
const systems=[{page:0,x:40,y:100,w:500,h:80.5},{page:1,x:40,y:60,w:500,h:80}],cues=[{tick:0,system:0,x:60},{tick:1920,system:0,x:540},{tick:1920,system:1,x:60},{tick:200000,system:1,x:300.25}];
const encoded=new Uint8Array([...Buffer.from('BCUE'),1,0,...varuint(systems.length),...systems.flatMap(s=>[...varuint(s.page),...f32(s.x),...f32(s.y),...f32(s.w),...f32(s.h)]),...varuint(cues.length),...cues.flatMap((c,i)=>[...varuint(c.tick-(cues[i-1]?.tick??0)),...varuint(c.system),...f32(c.x)])]);
const decoded=decodeCues(encoded);assert.deepEqual(JSON.parse(inspect_cues(encoded)),decoded);
for(const tick of [-20,0,500,1920,3000,200000,300000])for(const system of [0,1,2])for(const x of [20,60,250,540])for(const near of [0,2000,200000]){
  const actual=JSON.parse(inspect_cue_position(encoded,tick,system,x,near));assert.deepEqual(actual,{cursor:cursorAtTick(decoded,tick),line:lineAtTime(decoded,tick),tickAt:tickAt(decoded,system,x,near),lineTime:timeOfLine(decoded,system,near)});
}
for(let n=0;n<encoded.length;n++){assert.throws(()=>decodeCues(encoded.subarray(0,n)));assert.throws(()=>inspect_cues(encoded.subarray(0,n)))}
const wrap=new Uint8Array([...Buffer.from('BCUE'),1,0,1,0,...f32(0),...f32(0),...f32(1),...f32(1),2,...varuint(4294967295n),0,...f32(0),...varuint(2),0,...f32(1)]);
assert.deepEqual(JSON.parse(inspect_cues(wrap)),decodeCues(wrap));
for(let i=0;i<100;i++){
  const ss=Array.from({length:1+random(5)},(_,page)=>({page,x:random(200)-100,y:random(200)-100,w:1+random(500),h:1+random(100)}));let time=0;
  const cs=Array.from({length:1+random(20)},()=>({tick:time+=random(200),system:random(ss.length),x:random(500)-250}));
  const input=new Uint8Array([...Buffer.from('BCUE'),1,0,...varuint(ss.length),...ss.flatMap(s=>[...varuint(s.page),...f32(s.x),...f32(s.y),...f32(s.w),...f32(s.h)]),...varuint(cs.length),...cs.flatMap((c,j)=>[...varuint(c.tick-(cs[j-1]?.tick??0)),...varuint(c.system),...f32(c.x)])]);
  const expected=decodeCues(input);assert.deepEqual(JSON.parse(inspect_cues(input)),expected);
  for(let j=0;j<8;j++){const tick=random(time+100),system=random(ss.length+1),x=random(600)-300,near=random(time+100),actual=JSON.parse(inspect_cue_position(input,tick,system,x,near));assert.deepEqual(actual,{cursor:cursorAtTick(expected,tick),line:lineAtTime(expected,tick),tickAt:tickAt(expected,system,x,near),lineTime:timeOfLine(expected,system,near)})}
}
for(const broken of [new Uint8Array([...Buffer.from('BCUE'),2,0,0,0]),new Uint8Array([...Buffer.from('BCUE'),1,0,0,1,0,0,...f32(0)]),new Uint8Array([...Buffer.from('BCUE'),1,0,...varuint(9007199254740992n)]),new Uint8Array([...Buffer.from('BCUE'),1,0,255,127])]){
  assert.throws(()=>decodeCues(broken));assert.throws(()=>inspect_cues(broken));
}
for(const name of ['ode-mml','ode-mxl','minuet-musicxml','twinkle-kar','frere-mml']){
  const data=new Uint8Array(readFileSync(new URL(`./fixtures/${name}.bdf`,import.meta.url))),document=await BdfDocument.open(new BufferSource(data)),music=await document.play(document.manifest.views[0]);
  assert.ok(music,`${name}: upstream music data`);const actual=JSON.parse(inspect_document_music(data));assert.deepEqual(actual,{seq:[...music.seq],cues:music.cues},`${name}: BDF play data`);
  assert.deepEqual(JSON.parse(inspect_smf(music.seq)),parseSmf(music.seq),`${name}: MIDI sequence`);
}
console.log(`Music compatibility: ${fixtures.length} MIDI fixtures, cue timelines, and five upstream BDF files match.`);
