///|
#external
priv type SynthContext

///|
#external
priv type SynthGraph

///|
#external
priv type SynthVoice

///|
extern "js" fn synth_graph(
  context : SynthContext,
  volume : Double,
) -> SynthGraph =
  #|(ctx,volume) => {const master=ctx.createGain();master.gain.value=volume;const limit=ctx.createDynamicsCompressor();limit.threshold.value=-8;limit.knee.value=6;limit.ratio.value=8;master.connect(limit).connect(ctx.destination);const channels=[];for(let i=0;i<16;i++){const input=ctx.createGain(),pan=typeof ctx.createStereoPanner==='function'?ctx.createStereoPanner():null;if(pan)input.connect(pan).connect(master);else input.connect(master);channels.push({input,pan})}return {ctx,master,channels,waves:new Map(),buffers:new Map()}}

///|
extern "js" fn synth_now(graph : SynthGraph) -> Double =
  #|(g) => g.ctx.currentTime

///|
extern "js" fn synth_rate(graph : SynthGraph) -> Double =
  #|(g) => g.ctx.sampleRate

///|
extern "js" fn synth_pow(base : Double, exponent : Double) -> Double =
  #|(base,exponent) => Math.pow(base,exponent)

///|
extern "js" fn synth_exp(value : Double) -> Double =
  #|(value) => Math.exp(value)

///|
extern "js" fn synth_level(
  graph : SynthGraph,
  channel : Int32,
  gain : Double,
  pan : Double,
  when : Double,
  jump : Bool,
) -> Unit =
  #|(g,ch,gain,pan,when,jump) => {const c=g.channels[ch],set=(p,v)=>{if(!jump)p.setTargetAtTime(v,when,0.005);else{p.cancelScheduledValues(0);p.setValueAtTime(v,when)}};set(c.input.gain,gain);if(c.pan)set(c.pan.pan,pan)}

///|
extern "js" fn synth_melodic(
  graph : SynthGraph,
  channel : Int32,
  wave : String,
  frequency : Double,
  rate : Double,
  bend : Double,
  duty : Double,
  filter : Double,
  peak : Double,
  held : Double,
  attack_level : Double,
  sustain : Double,
  decay : Double,
  off : Double,
  release : Double,
  when : Double,
) -> SynthVoice =
  #|(g,ch,wave,f,rate,bend,duty,filter,peak,held,attackLevel,sustain,decay,off,release,when) => {
  #| const ctx=g.ctx,noise=hold=>{const name=`noise${hold}`;let b=g.buffers.get(name);if(!b){const n=ctx.sampleRate;b=ctx.createBuffer(1,n,n);const d=b.getChannelData(0);for(let i=0;i<n;i+=hold)d.fill(Math.random()*2-1,i,i+hold);g.buffers.set(name,b)}return b};
  #| const periodic=name=>{let w=g.waves.get(name);if(!w){let re,im;if(name.startsWith('pulse')){const n=64;re=new Float32Array(n);im=new Float32Array(n);for(let k=1;k<n;k++){re[k]=2/(k*Math.PI)*Math.sin(2*Math.PI*k*duty);im[k]=2/(k*Math.PI)*(1-Math.cos(2*Math.PI*k*duty))}}else{im=name==='organ'?new Float32Array([0,1,0.8,0.5,0.35,0,0.25,0,0.18]):Float32Array.from({length:16},(_,k)=>k===0?0:1/k**1.6);re=new Float32Array(im.length)}w=ctx.createPeriodicWave(re,im);g.waves.set(name,w)}return w};
  #| let src,detune;if(wave==='noise'){src=ctx.createBufferSource();src.buffer=noise(4);src.loop=true;src.playbackRate.value=rate;detune=src.detune}else{src=ctx.createOscillator();src.frequency.value=f;if(wave==='pulse')src.setPeriodicWave(periodic(`pulse${duty}`));else if(wave==='organ'||wave==='piano')src.setPeriodicWave(periodic(wave));else src.type=wave;detune=src.detune}detune.value=bend;
  #| const env=ctx.createGain();let out=src;if(filter>=0){const lp=ctx.createBiquadFilter();lp.type='lowpass';lp.frequency.value=filter;out=src.connect(lp)}out.connect(env).connect(g.channels[ch].input);
  #| const gain=env.gain;gain.setValueAtTime(0,when);gain.linearRampToValueAtTime(attackLevel,held);if(sustain<1)gain.setTargetAtTime(peak*sustain,held,decay);gain.setTargetAtTime(0,off,release/3);const stop=off+release*2+0.02;if(wave==='noise')src.start(when,Math.random()*0.5);else src.start(when);src.stop(stop);src.onended=()=>env.disconnect();return {channel:ch,start:when,stop,sources:[src],env,detune:[detune]};
  #|}

///|
extern "js" fn synth_drum_new(graph : SynthGraph, when : Double) -> SynthVoice =
  #|(g,when) => {const env=g.ctx.createGain();env.connect(g.channels[9].input);return {channel:9,start:when,stop:when,sources:[],env,detune:[]}}

///|
extern "js" fn synth_drum_tone(
  graph : SynthGraph,
  voice : SynthVoice,
  wave : String,
  from : Double,
  to : Double,
  sweep : Double,
  gain : Double,
  duration : Double,
  when : Double,
) -> Unit =
  #|(g,v,wave,from,to,sweep,gain,duration,when) => {const o=g.ctx.createOscillator(),env=g.ctx.createGain();o.type=wave;o.frequency.setValueAtTime(from,when);o.frequency.exponentialRampToValueAtTime(to,when+sweep);env.gain.setValueAtTime(gain,when);env.gain.exponentialRampToValueAtTime(0.0001,when+duration);env.connect(v.env);o.connect(env);o.start(when);v.sources.push(o)}

///|
extern "js" fn synth_drum_noise(
  graph : SynthGraph,
  voice : SynthVoice,
  kind : String,
  freq : Double,
  gain : Double,
  duration : Double,
  when : Double,
) -> Unit =
  #|(g,v,kind,freq,gain,duration,when) => {const ctx=g.ctx;let b=g.buffers.get('noise1');if(!b){const n=ctx.sampleRate;b=ctx.createBuffer(1,n,n);const d=b.getChannelData(0);for(let i=0;i<n;i++)d[i]=Math.random()*2-1;g.buffers.set('noise1',b)}const src=ctx.createBufferSource(),f=ctx.createBiquadFilter(),env=ctx.createGain();src.buffer=b;src.loop=true;f.type=kind;f.frequency.value=freq;env.gain.setValueAtTime(gain,when);env.gain.exponentialRampToValueAtTime(0.0001,when+duration);env.connect(v.env);src.connect(f).connect(env);src.start(when,Math.random()*0.5);v.sources.push(src)}

///|
extern "js" fn synth_drum_finish(voice : SynthVoice, stop : Double) -> Unit =
  #|(v,stop) => {v.stop=stop;for(const s of v.sources)s.stop(stop);v.sources[0].onended=()=>v.env.disconnect()}

///|
extern "js" fn synth_click(
  graph : SynthGraph,
  accent : Bool,
  when : Double,
) -> SynthVoice =
  #|(g,accent,when) => {const src=g.ctx.createOscillator(),env=g.ctx.createGain(),stop=when+0.055;src.type='sine';src.frequency.value=accent?1760:1320;env.gain.setValueAtTime(0.0001,when);env.gain.exponentialRampToValueAtTime(accent?0.18:0.12,when+0.001);env.gain.exponentialRampToValueAtTime(0.0001,when+0.045);src.connect(env).connect(g.master);src.start(when);src.stop(stop);src.onended=()=>env.disconnect();return {channel:-1,start:when,stop,sources:[src],env,detune:[]}}

///|
extern "js" fn voice_channel(voice : SynthVoice) -> Int32 =
  #|(v) => v.channel

///|
extern "js" fn voice_end(voice : SynthVoice) -> Double =
  #|(v) => v.stop

///|
extern "js" fn voice_bend(
  voice : SynthVoice,
  cents : Double,
  when : Double,
) -> Unit =
  #|(v,cents,when) => {for(const d of v.detune)d.setValueAtTime(cents,when)}

///|
extern "js" fn voice_release(
  voice : SynthVoice,
  at : Double,
  tc : Double,
) -> Unit =
  #|(v,at,tc) => {const gain=v.env.gain;if(v.start<at){if(typeof gain.cancelAndHoldAtTime==='function')gain.cancelAndHoldAtTime(at);else gain.cancelScheduledValues(at);gain.setTargetAtTime(0,at,tc)}const stop=v.start<at?at+tc*8:at;for(const s of v.sources)try{s.stop(stop)}catch{}v.stop=Math.min(v.stop,stop)}

///|
extern "js" fn synth_disconnect(graph : SynthGraph) -> Unit =
  #|(g) => g.master.disconnect()
