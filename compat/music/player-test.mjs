import assert from 'node:assert/strict';
import { MusicPlayer } from '../../node_modules/@bdfkit/render/dist/player.js';
import { parseSmf } from '../../node_modules/@bdfkit/core/dist/index.js';
import { bdf_music_player } from '../../_build/js/debug/build/browser/browser.js';
const u16=n=>[n>>8&255,n&255],u32=n=>[n>>>24,n>>16&255,n>>8&255,n&255],vlq=n=>{const out=[n&127];while(n>>>=7)out.unshift((n&127)|128);return out},chunk=(s,d)=>[...Buffer.from(s),...u32(d.length),...d];
const track=(events)=>{let last=0;return [...events,[events.at(-1)?.[0]??0,255,47,0]].flatMap(([t,...data])=>{const delta=vlq(t-last);last=t;return [...delta,...data]})};
const smf=(events,division=480)=>new Uint8Array([...chunk('MThd',[...u16(0),...u16(1),...u16(division)]),...chunk('MTrk',track(events))]);
const cues={systems:[{page:0,x:50,y:100,w:500,h:80},{page:1,x:50,y:300,w:500,h:80}],cues:[{tick:0,system:0,x:100},{tick:480,system:0,x:300},{tick:960,system:1,x:100},{tick:1920,system:1,x:500}]};
function fakeAudio(){
 const sources=[],gains=[],filters=[],pans=[];
 const param=(value=0)=>{const p={value,calls:[]};for(const m of ['setValueAtTime','linearRampToValueAtTime','exponentialRampToValueAtTime','setTargetAtTime','cancelScheduledValues','cancelAndHoldAtTime'])p[m]=(...args)=>{p.calls.push([m,...args]);return p};return p};
 const node=(props={})=>({connect:n=>n,disconnect(){},...props});
 const source=(kind,props)=>{const s=node({kind,detune:param(),...props});s.start=(when,offset)=>{s.when=when;s.offset=offset;sources.push(s)};s.stop=when=>{s.end=when};return s};
 const ctx={currentTime:0,sampleRate:8000,state:'suspended',outputLatency:0,destination:node(),resumed:0,closed:false,
 createGain(){const x=node({gain:param(1)});gains.push(x);return x},createDynamicsCompressor:()=>node({threshold:param(),knee:param(),ratio:param()}),createStereoPanner(){const x=node({pan:param()});pans.push(x);return x},createBiquadFilter(){const x=node({type:'lowpass',frequency:param(350),Q:param(1)});filters.push(x);return x},
 createOscillator:()=>source('osc',{type:'sine',frequency:param(440),setPeriodicWave(w){this.wave=w}}),createBufferSource:()=>source('buffer',{buffer:null,loop:false,playbackRate:param(1)}),createBuffer:(_channels,length)=>({getChannelData:()=>new Float32Array(length)}),createPeriodicWave:(real,imag)=>({real:[...real],imag:[...imag]}),resume(){this.resumed++;this.state='running';return Promise.resolve()},close(){this.closed=true;return Promise.resolve()}};
 const snapshot=()=>({sources:sources.map(s=>({kind:s.kind,type:s.type,frequency:s.frequency&&{value:s.frequency.value,calls:s.frequency.calls},rate:s.playbackRate?.value,detune:{value:s.detune.value,calls:s.detune.calls},wave:s.wave,when:s.when,offset:s.offset,end:s.end})),gains:gains.map(x=>({value:x.gain.value,calls:x.gain.calls})),filters:filters.map(x=>({type:x.type,frequency:x.frequency.value})),pans:pans.map(x=>x.pan.calls),resumed:ctx.resumed,closed:ctx.closed});
 return {ctx,snapshot,sources};
}
const realSet=globalThis.setInterval,realClear=globalThis.clearInterval,realRandom=Math.random;let timers=new Map(),nextTimer=1;
globalThis.setInterval=(fn)=>{const id=nextTimer++;timers.set(id,fn);return id};globalThis.clearInterval=id=>timers.delete(id);Math.random=()=>0.25;
const tick=()=>{for(const fn of [...timers.values()])fn()};
const create=(kind,bytes,score,ctx)=>kind==='upstream'?new MusicPlayer(bytes,score,{context:()=>ctx}):bdf_music_player(bytes,score,{context:()=>ctx});
async function exercise(kind){
 timers=new Map();const notes=[];for(let i=0;i<8;i++){notes.push([i*480,0x90,60+i,100],[i*480+384,0x80,60+i,0])}const bytes=smf([[0,0xc0,80],[0,0xb0,70,40],...notes]),{ctx,snapshot}=fakeAudio(),p=create(kind,bytes,cues,ctx),updates=[],positions=[];p.onUpdate=()=>updates.push([p.state,p.position]);let ended=0;p.onEnd=()=>ended++;
 const sample=()=>positions.push({state:p.state,playing:p.playing,position:p.position,duration:p.duration,bpm:p.bpm,baseBpm:p.baseBpm,speed:p.speedPercent,tempoScale:p.tempoScale,cursor:p.cursorAt(p.position),time:p.timeAt(0,200),available:p.metronomeAvailable});
 sample();await p.play();sample();ctx.currentTime=0.45;tick();sample();ctx.currentTime=0.75;tick();p.pause();sample();ctx.currentTime=2;tick();await p.play();sample();p.seek(3);sample();p.setSpeedPercent(150);sample();p.setMetronome(true);ctx.currentTime=2.6;tick();sample();p.setMetronome(false);p.seek(100);sample();p.stop();sample();p.seek(0.5);sample();await p.play();ctx.currentTime=20;tick();sample();p.dispose();return {sequence:p.sequence,positions,updates,ended,graph:snapshot()};
}
try{
 assert.deepEqual(await exercise('moon'),await exercise('upstream'),'music transport, timing, envelopes and callbacks');
 {
  const sequence=parseSmf(smf([[0,0xc0,80],[0,0x90,60,100],[480,0x80,60,0]])),results=[];
  for(const kind of ['upstream','moon']){timers=new Map();const {ctx,snapshot}=fakeAudio(),p=create(kind,sequence,cues,ctx);assert.equal(p.sequence,sequence,'a parsed sequence is exposed unchanged');await p.play();results.push(snapshot());p.dispose()}
  assert.deepEqual(results[1],results[0],'parsed MIDI sequence playback');
 }
 for(let program=0;program<128;program++){
  const bytes=smf([[0,0xc0,program],[0,0xb0,70,95],[0,0xe0,0,0x60],[0,0x90,60,100],[480,0x80,60,0]]),results=[];
  for(const kind of ['upstream','moon']){timers=new Map();const {ctx,snapshot}=fakeAudio(),p=create(kind,bytes,null,ctx);await p.play();results.push(snapshot());p.dispose()}
  assert.deepEqual(results[1],results[0],`program ${program} oscillator, filter and envelope`);
 }
 for(const key of [35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,55,57,59,60]){
  const bytes=smf([[0,0x99,key,100],[480,0x89,key,0]]),results=[];
  for(const kind of ['upstream','moon']){timers=new Map();const {ctx,snapshot}=fakeAudio(),p=create(kind,bytes,null,ctx);await p.play();results.push(snapshot());p.dispose()}
  assert.deepEqual(results[1],results[0],`drum ${key} sources and envelope`);
 }
 {
  const chord=[];for(let i=0;i<100;i++)chord.push([480,0x91,20+i,100]);for(let i=0;i<100;i++)chord.push([960,0x81,20+i,0]);
  const bytes=smf([[0,0x90,60,100],[120,0xb0,64,127],[240,0x80,60,0],[240,0xe0,0,0x60],[300,0xb0,7,40],[360,0xb0,10,0],[400,0xb0,11,80],[450,0xff,0x51,3,0x09,0x27,0xc0],[480,0xff,0x58,4,3,2,24,8],...chord,[960,0xb0,121,0],[1440,0x90,65,90],[1920,0x80,65,0]]),results=[];
  for(const kind of ['upstream','moon']){timers=new Map();const {ctx,snapshot}=fakeAudio(),p=create(kind,bytes,cues,ctx),states=[];p.onUpdate=()=>states.push([p.state,p.position]);await p.play();p.setMetronome(true);for(const t of [0.2,0.5,0.8,1.0,1.4]){ctx.currentTime=t;tick()}p.seek(0.32);p.setSpeedPercent(75);ctx.currentTime=1.6;tick();p.pause();p.seek(0.7);await p.play();ctx.currentTime=1.8;tick();results.push({graph:snapshot(),states,position:p.position,cursor:p.cursorAt(p.position)});p.dispose()}
  assert.deepEqual(results[1],results[0],'sustain, bend, controller reset, tempo and meter changes, seeking and voice limits');
 }
 {
  const bytes=smf([[0,0x90,60,100],[40,0x80,60,0]],0xe728),results=[];
  for(const kind of ['upstream','moon']){timers=new Map();const {ctx,snapshot}=fakeAudio(),p=create(kind,bytes,null,ctx);p.setMetronome(true);await p.play();p.setSpeedPercent(120);results.push({duration:p.duration,available:p.metronomeAvailable,bpmAvailable:p.bpmAvailable,enabled:p.metronomeEnabled,graph:snapshot()});p.dispose()}
  assert.deepEqual(results[1],results[0],'SMPTE timing and metronome availability');
 }
 console.log('MusicPlayer compatibility: scheduling, transport, metronome, all MIDI programs and drums match upstream.');
}finally{globalThis.setInterval=realSet;globalThis.clearInterval=realClear;Math.random=realRandom}
