///|
/// A browser audio element, or null to create one outside the page.
#external
pub type BrowserAudioElement

///|
/// JavaScript cue index with `systems` and `cues` arrays, or null.
#external
pub type BrowserAudioCues

///|
/// JavaScript audio player, exposing the upstream AudioPlayer methods and callbacks.
#external
pub type BrowserAudioPlayer

///|
#external
priv type BrowserAudioCursor

///|
#external
priv type BrowserAudioTime

///|
extern "js" fn audio_cues_present(cues : BrowserAudioCues) -> Bool =
  #|(cues) => cues != null

///|
extern "js" fn audio_cue_count(cues : BrowserAudioCues) -> Int32 =
  #|(cues) => cues.cues.length

///|
extern "js" fn audio_system_page(cues : BrowserAudioCues, i : Double) -> Double =
  #|(cues,i) => cues.systems[i].page

///|
extern "js" fn audio_system_value(
  cues : BrowserAudioCues,
  i : Double,
  key : String,
) -> Double =
  #|(cues,i,key) => cues.systems[i][key]

///|
extern "js" fn audio_cue_tick(cues : BrowserAudioCues, i : Int32) -> Double =
  #|(cues,i) => cues.cues[i].tick

///|
extern "js" fn audio_cue_system(cues : BrowserAudioCues, i : Int32) -> Double =
  #|(cues,i) => cues.cues[i].system

///|
extern "js" fn empty_audio_cues() -> BrowserAudioCues =
  #|() => ({systems:[],cues:[]})

///|
extern "js" fn no_audio_cues() -> BrowserAudioCues =
  #|() => null

///|
extern "js" fn add_audio_system(
  cues : BrowserAudioCues,
  page : UInt32,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit =
  #|(cues,page,x,y,w,h) => cues.systems.push({page:page>>>0,x,y,w,h})

///|
extern "js" fn add_audio_cue(
  cues : BrowserAudioCues,
  tick : UInt32,
  system : UInt32,
  x : Double,
) -> Unit =
  #|(cues,tick,system,x) => cues.cues.push({tick:tick>>>0,system:system>>>0,x})

///|
fn audio_cues_from_core(cues : @core.Cues?) -> BrowserAudioCues {
  match cues {
    None => no_audio_cues()
    Some(index) => {
      let result = empty_audio_cues()
      for system in index.systems {
        add_audio_system(
          result,
          system.page,
          system.x,
          system.y,
          system.width,
          system.height,
        )
      }
      for cue in index.cues {
        add_audio_cue(result, cue.tick, cue.system, cue.x)
      }
      result
    }
  }
}

///|
extern "js" fn audio_current_cues(
  handle : BrowserAudioPlayer,
) -> BrowserAudioCues =
  #|(handle) => handle.cues

///|
extern "js" fn audio_set_cues(
  handle : BrowserAudioPlayer,
  cues : BrowserAudioCues,
) -> Unit =
  #|(handle,cues) => {handle.cues=cues??null}

///|
extern "js" fn create_audio_handle(
  data : Bytes,
  media_type : String,
  element : BrowserAudioElement,
) -> BrowserAudioPlayer =
  #|(data,type,element) => {const blob=data instanceof Blob?data:new Blob([data],{type}),el=element??new Audio();if(typeof el.addEventListener!=='function'||typeof el.removeEventListener!=='function')throw new TypeError('invalid audio element');return {element:el,url:URL.createObjectURL(blob),error:undefined,onUpdate:undefined,onEnd:undefined,onError:undefined}}

///|
extern "js" fn audio_playing(handle : BrowserAudioPlayer) -> Bool =
  #|(h) => !h.element.paused&&!h.element.ended

///|
extern "js" fn audio_position(handle : BrowserAudioPlayer) -> Double =
  #|(h) => h.element.currentTime

///|
extern "js" fn audio_normal_speed(percent : Double) -> Double =
  #|(percent) => Number.isFinite(percent)?Math.max(25,Math.min(200,Math.round(percent))):0

///|
extern "js" fn audio_set_speed(
  handle : BrowserAudioPlayer,
  percent : Double,
) -> Unit =
  #|(h,percent) => {h.element.defaultPlaybackRate=h.element.playbackRate=percent/100}

///|
extern "js" fn audio_has_error(handle : BrowserAudioPlayer) -> Bool =
  #|(h) => !!h.error

///|
extern "js" fn audio_reject_error(
  handle : BrowserAudioPlayer,
) -> @js_async.Promise[Unit] =
  #|(h) => Promise.reject(h.error)

///|
extern "js" fn audio_start(
  handle : BrowserAudioPlayer,
) -> @js_async.Promise[Unit] =
  #|(h) => h.element.play()

///|
extern "js" fn audio_pause(handle : BrowserAudioPlayer) -> Unit =
  #|(h) => h.element.pause()

///|
extern "js" fn audio_seek(
  handle : BrowserAudioPlayer,
  seconds : Double,
) -> Unit =
  #|(h,seconds) => {const d=Number.isFinite(h.element.duration)&&h.element.duration>0?h.element.duration:0;h.element.currentTime=Math.max(0,d>0?Math.min(d,seconds):seconds)}

///|
extern "js" fn audio_rewind(handle : BrowserAudioPlayer) -> Unit =
  #|(h) => {try{h.element.currentTime=0}catch{}}

///|
extern "js" fn audio_notify(handle : BrowserAudioPlayer) -> Unit =
  #|(h) => h.onUpdate?.()

///|
extern "js" fn audio_notify_end(handle : BrowserAudioPlayer) -> Unit =
  #|(h) => h.onEnd?.()

///|
extern "js" fn audio_failure(handle : BrowserAudioPlayer) -> Unit =
  #|(h) => {const e=h.element.error,why=e?.code===4?'this browser does not play audio of this format':e?.code===3?'the audio could not be decoded':'the audio could not be loaded';h.error=new Error(e?.message?`${why} (${e.message})`:why);h.onError?.(h.error)}

///|
extern "js" fn audio_cursor(
  page : Double,
  system : Double,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> BrowserAudioCursor =
  #|(page,system,x,y,w,h) => ({page,system,x,y,w,h})

///|
extern "js" fn audio_no_cursor() -> BrowserAudioCursor =
  #|() => null

///|
extern "js" fn audio_time(seconds : Double) -> BrowserAudioTime =
  #|(seconds) => seconds

///|
extern "js" fn audio_no_time() -> BrowserAudioTime =
  #|() => null

///|
extern "js" fn audio_dispose(handle : BrowserAudioPlayer) -> Unit =
  #|(h) => {for(const [name,fn] of h.listeners)h.element.removeEventListener(name,fn);h.element.pause();h.element.removeAttribute('src');h.element.load();URL.revokeObjectURL(h.url)}

///|
extern "js" fn audio_install(
  handle : BrowserAudioPlayer,
  event : (Int32) -> Unit,
  state : () -> String,
  position : () -> Double,
  play : () -> @js_async.Promise[Unit],
  pause : () -> Unit,
  stop : () -> Unit,
  seek : (Double) -> Unit,
  speed : (Double) -> Unit,
  cursor : (Double) -> BrowserAudioCursor,
  time : (Double) -> BrowserAudioTime,
  dispose : () -> Unit,
) -> Unit =
  #|(h,event,state,position,play,pause,stop,seek,speed,cursor,time,dispose) => {
  #| Object.defineProperties(h,{state:{get:state},playing:{get:()=>!h.element.paused&&!h.element.ended},duration:{get:()=>Number.isFinite(h.element.duration)&&h.element.duration>0?h.element.duration:0},position:{get:position},speedPercent:{get:()=>Math.round(h.element.playbackRate*100)}});
  #| Object.assign(h,{play,pause,stop,seek,setSpeedPercent:speed,cursorAt:cursor,timeAt:time,dispose});
  #| h.listeners=[['play',()=>event(0)],['pause',()=>event(1)],['seeked',()=>event(1)],['durationchange',()=>event(1)],['ratechange',()=>event(1)],['ended',()=>event(2)],['error',()=>event(3)]];
  #| try{for(const [name,fn] of h.listeners)h.element.addEventListener(name,fn);h.element.preload='metadata';h.element.src=h.url}catch(error){for(const [name,fn] of h.listeners){try{h.element.removeEventListener(name,fn)}catch{}}URL.revokeObjectURL(h.url);throw error}
  #|}

///|
priv struct AudioState {
  handle : BrowserAudioPlayer
  mut idle : Bool
}

///|
fn AudioState::state(self : AudioState) -> String {
  if audio_playing(self.handle) {
    "playing"
  } else if self.idle {
    "stopped"
  } else {
    "paused"
  }
}

///|
fn AudioState::position(self : AudioState) -> Double {
  if self.idle && !audio_playing(self.handle) {
    0.0
  } else {
    audio_position(self.handle)
  }
}

///|
fn AudioState::event(self : AudioState, kind : Int32) -> Unit {
  if kind == 0 {
    self.idle = false
  } else if kind == 2 {
    self.idle = true
    audio_rewind(self.handle)
    audio_notify(self.handle)
    audio_notify_end(self.handle)
    return
  } else if kind == 3 {
    self.idle = true
    audio_failure(self.handle)
  }
  audio_notify(self.handle)
}

///|
fn audio_line_cursor(
  cues : BrowserAudioCues,
  milliseconds : Double,
) -> BrowserAudioCursor {
  if !audio_cues_present(cues) ||
    audio_cue_count(cues) == 0 ||
    !(milliseconds >= audio_cue_tick(cues, 0)) {
    return audio_no_cursor()
  }
  let mut lo = 0
  let mut hi = audio_cue_count(cues) - 1
  while lo < hi {
    let mid = (lo + hi + 1) / 2
    if audio_cue_tick(cues, mid) <= milliseconds {
      lo = mid
    } else {
      hi = mid - 1
    }
  }
  let system = audio_cue_system(cues, lo)
  audio_cursor(
    audio_system_page(cues, system),
    system,
    audio_system_value(cues, system, "x"),
    audio_system_value(cues, system, "y"),
    audio_system_value(cues, system, "w"),
    audio_system_value(cues, system, "h"),
  )
}

///|
fn audio_line_time(
  cues : BrowserAudioCues,
  system : Double,
  near : Double,
) -> BrowserAudioTime {
  if !audio_cues_present(cues) {
    return audio_no_time()
  }
  let mut best : Double? = None
  let mut far = 9218868437227405312UL.reinterpret_as_double()
  for i in 0..<audio_cue_count(cues) {
    if audio_cue_system(cues, i) == system {
      let tick = audio_cue_tick(cues, i)
      let distance = (tick - near).abs()
      if distance < far {
        best = Some(tick)
        far = distance
      }
    }
  }
  match best {
    Some(tick) => audio_time(tick / 1000.0)
    None => audio_no_time()
  }
}

///|
fn make_audio_player(
  data : Bytes,
  media_type : String,
  cues : BrowserAudioCues,
  element : BrowserAudioElement,
) -> BrowserAudioPlayer {
  let handle = create_audio_handle(data, media_type, element)
  let player : AudioState = { handle, idle: true, }
  audio_set_cues(handle, cues)
  audio_install(
    handle,
    kind => player.event(kind),
    () => player.state(),
    () => player.position(),
    () => {
      if audio_has_error(handle) {
        audio_reject_error(handle)
      } else {
        player.idle = false
        audio_start(handle)
      }
    },
    () => audio_pause(handle),
    () => {
      if player.state() != "stopped" {
        player.idle = true
        audio_pause(handle)
        audio_rewind(handle)
        audio_notify(handle)
      }
    },
    seconds => {
      player.idle = false
      audio_seek(handle, seconds)
      audio_notify(handle)
    },
    percent => {
      let value = audio_normal_speed(percent)
      if value > 0.0 {
        audio_set_speed(handle, value)
      }
    },
    seconds => {
      audio_line_cursor(audio_current_cues(handle), seconds * 1000.0 + 0.5)
    },
    system => {
      audio_line_time(
        audio_current_cues(handle),
        system,
        player.position() * 1000.0,
      )
    },
    () => {
      audio_dispose(handle)
      player.idle = true
    },
  )
  handle
}

///|
/// Create an audio player from bytes or a Blob, a MIME type, optional cue object, and optional audio element.
#export_name("bdf_audio_player")
pub fn bdf_audio_player(
  data : Bytes,
  media_type : String,
  cues : BrowserAudioCues,
  element : BrowserAudioElement,
) -> BrowserAudioPlayer {
  make_audio_player(data, media_type, cues, element)
}

///|
extern "js" fn install_audio_source(
  host : BrowserHost,
  load : (BrowserAudioElement) -> @js_async.Promise[BrowserAudioPlayer],
) -> Unit =
  #|(host,load) => {
  #| const state=host[Symbol.for('f4ah6o.bdf.pageLayout')]??host[Symbol.for('f4ah6o.bdf.sheet')],previous=state.dispose,players=new Set();let disposed=false,queue=Promise.resolve();
  #| state.audioPlayer=async element=>{if(disposed)throw new Error('BDF view is not mounted');const job=queue.then(()=>{if(disposed)throw new Error('BDF view is not mounted');return load(element)});queue=job.then(()=>{},()=>{});const player=await job;if(disposed){player.dispose();throw new Error('BDF view is not mounted')}players.add(player);const dispose=player.dispose;player.dispose=()=>{if(players.delete(player))dispose()};return player};
  #| state.dispose=()=>{if(disposed)return;disposed=true;for(const player of players)player.dispose();previous()};
  #|}

///|
extern "js" fn audio_player_for_view(
  host : BrowserHost,
  element : BrowserAudioElement,
) -> @js_async.Promise[BrowserAudioPlayer] =
  #|(host,element) => {const state=host[Symbol.for('f4ah6o.bdf.pageLayout')],sheet=host[Symbol.for('f4ah6o.bdf.sheet')];if(!state&&!sheet)return Promise.reject(new Error('BDF view is not mounted'));const owner=state??sheet;return owner.audioPlayer?owner.audioPlayer(element):Promise.resolve(null)}

///|
/// Load a mounted view's recording and cues, returning null if it has no audio.
/// The host owns the player and disposes it when the view is unmounted.
#export_name("bdf_audio_player_for_view_async")
pub fn bdf_audio_player_for_view_async(
  host : BrowserHost,
  element : BrowserAudioElement,
) -> @js_async.Promise[BrowserAudioPlayer] {
  audio_player_for_view(host, element)
}

///|
fn install_view_audio(
  host : BrowserHost,
  document : BrowserDocument,
  view : @core.View,
  audio_loader? : (BrowserAudioElement) -> @js_async.Promise[BrowserAudioPlayer],
) -> Unit {
  if view.play is Some(play) && play.audio is Some(hash) {
    let load = audio_loader.unwrap_or(element => {
      @js_async.Promise::from_async(() => {
        let cues = match play.cues {
          Some(cue_hash) => Some(@core.decode_cues(document.part(cue_hash)))
          None => None
        }
        let bytes = document.part(hash)
        let media_type = @core.audio_media_type(play.media_type)
        invoke_audio_create(() => {
          make_audio_player(
            bytes,
            media_type,
            audio_cues_from_core(cues),
            element,
          )
        }).wait()
      })
    })
    install_audio_source(host, load)
  }
}

///|
// Browser constructors and element setters may throw JavaScript exceptions.
extern "js" fn invoke_audio_create(
  create : () -> BrowserAudioPlayer,
) -> @js_async.Promise[BrowserAudioPlayer] =
  #|(create) => Promise.resolve().then(create)
