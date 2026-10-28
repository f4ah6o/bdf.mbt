import assert from 'node:assert/strict';
import { AudioPlayer } from '../../node_modules/@bdfkit/render/dist/audio.js';
import { bdf_audio_player } from '../../_build/js/debug/build/browser/browser.js';

const cues={systems:[{page:0,x:32,y:400,w:296,h:16},{page:0,x:32,y:416,w:296,h:32},{page:1,x:32,y:456,w:296,h:16}],cues:[{tick:1500,system:0,x:32},{tick:4500,system:1,x:32},{tick:8000,system:2,x:32},{tick:12000,system:0,x:32},{tick:20000,system:2,x:32}]};
class FakeAudio extends EventTarget {
  paused=true;ended=false;duration=NaN;playbackRate=1;defaultPlaybackRate=1;preload='';src='';error=null;loads=0;time=0;refuse=null;
  get currentTime(){return this.time}set currentTime(value){this.time=value;this.ended=false;this.dispatchEvent(new Event('seeked'))}
  play(){if(this.refuse)return Promise.reject(this.refuse);if(this.ended)this.time=0;this.ended=false;this.paused=false;this.dispatchEvent(new Event('play'));return Promise.resolve()}
  pause(){if(!this.paused){this.paused=true;this.dispatchEvent(new Event('pause'))}}
  load(){this.loads++}removeAttribute(name){if(name==='src')this.src=''}
  loaded(duration){this.duration=duration;this.dispatchEvent(new Event('durationchange'))}
  end(){this.time=this.duration;this.paused=true;this.ended=true;this.dispatchEvent(new Event('pause'));this.dispatchEvent(new Event('ended'))}
}
const make=(kind,el,source=cues)=>kind==='upstream'?new AudioPlayer(new Uint8Array([1,2,3]),'audio/mpeg',source,{element:el}):bdf_audio_player(new Uint8Array([1,2,3]),'audio/mpeg',source,el);
async function exercise(kind){
 const el=new FakeAudio(),player=make(kind,el),trace=[];let end=0;player.onUpdate=()=>trace.push([player.state,player.position]);player.onEnd=()=>end++;
 const snapshots=[];const snap=()=>snapshots.push({state:player.state,playing:player.playing,position:player.position,duration:player.duration,speed:player.speedPercent,cursor:player.cursorAt(player.position),line:player.timeAt(0)});
 snap();el.loaded(24);await player.play();el.time=5;snap();player.pause();snap();player.seek(11);snap();player.seek(99);snap();player.seek(-3);player.seek(8);player.stop();snap();player.stop();player.seek(4.5);snap();await player.play();el.end();snap();await player.play();snap();
 for(const value of [150,5,1000,NaN,25.5,Infinity]){player.setSpeedPercent(value);snap()}
 const url=el.src;player.dispose();snap();const count=trace.length;await el.play();assert.equal(trace.length,count,'listeners removed');await assert.rejects(fetch(url));
 return {snapshots,trace,end,loads:el.loads,src:el.src,preload:el.preload,defaultRate:el.defaultPlaybackRate};
}
assert.deepEqual(await exercise('moon'),await exercise('upstream'),'audio transport, callbacks, cues and speeds');
for(const [code,message] of [[4,''],[3,'bad frame'],[2,'network']]){
 const values=[];for(const kind of ['upstream','moon']){const el=new FakeAudio(),p=make(kind,el,null),events=[];p.onError=e=>events.push(e.message);p.onUpdate=()=>events.push(p.state);el.error={code,message};el.dispatchEvent(new Event('error'));let rejection;try{await p.play()}catch(e){rejection=e.message}values.push({events,rejection,error:p.error.message,state:p.state,cursor:p.cursorAt(1),time:p.timeAt(0)});p.dispose()}
 assert.deepEqual(values[1],values[0],`audio error ${code}`);
}
for(const kind of ['upstream','moon']){const el=new FakeAudio(),p=make(kind,el,null);el.refuse=new Error('NotAllowedError');await assert.rejects(p.play(),/NotAllowedError/);assert.equal(p.state,'paused');p.dispose()}
for(const kind of ['upstream','moon']){
 const dynamic=structuredClone(cues),el=new FakeAudio(),p=make(kind,el,dynamic);dynamic.cues[0].tick=1499.75;dynamic.systems[0].page=4294967297.5;
 assert.equal(p.cursorAt(1.49925)?.system,0,'caller cue changes and fractional milliseconds remain visible');
 assert.equal(p.cursorAt(1.49925)?.page,4294967297.5,'caller-provided page numbers are preserved');assert.equal(p.timeAt(0.5),null,'fractional system identifiers do not match integer systems');
 dynamic.cues.push({tick:4294967500,system:1,x:32});p.seek(4294967.5);assert.equal(p.timeAt(1),4294967.5,'large cue times do not wrap');
 p.cues=null;assert.equal(p.cursorAt(3),null);assert.equal(p.timeAt(0),null);p.dispose();
}
for(const kind of ['upstream','moon']){
 const el=new FakeAudio(),blob=new Blob([new Uint8Array([4,5,6])],{type:'audio/flac'}),p=kind==='upstream'?new AudioPlayer(blob,'',null,{element:el}):bdf_audio_player(blob,'',null,el);
 const response=await fetch(el.src);assert.equal(response.headers.get('content-type'),'audio/flac');assert.deepEqual(new Uint8Array(await response.arrayBuffer()),new Uint8Array([4,5,6]));p.dispose();
}
for(const kind of ['upstream','moon']){
 const el=new FakeAudio(),data=new Uint8Array([7,8,9]).buffer,p=kind==='upstream'?new AudioPlayer(data,'audio/wav',null,{element:el}):bdf_audio_player(data,'audio/wav',null,el);
 const response=await fetch(el.src);assert.equal(response.headers.get('content-type'),'audio/wav');assert.deepEqual(new Uint8Array(await response.arrayBuffer()),new Uint8Array([7,8,9]));p.dispose();
}
{
 const el=new FakeAudio(),create=URL.createObjectURL;let url;URL.createObjectURL=function(blob){url=create.call(this,blob);return url};
 try{Object.defineProperty(el,'src',{set(){throw new Error('bad source')},get(){return ''}});assert.throws(()=>bdf_audio_player(new Uint8Array([1]),'',null,el),/bad source/);await assert.rejects(fetch(url),'failed construction releases the object URL')}finally{URL.createObjectURL=create}
}
console.log('AudioPlayer compatibility: transport, callbacks, errors, speed and score cues match upstream.');
