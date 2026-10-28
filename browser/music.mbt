///|
#external
priv type PianoCanvas

///|
extern "js" fn piano_width(
  width : Double,
  end : Double,
  zoom : Double,
) -> Double =
  #|(width,end,zoom) => Math.min(16000,Math.max(width,Math.ceil(end*64*zoom)))

///|
extern "js" fn new_piano_canvas(
  host : BrowserHost,
  width : Double,
  height : Double,
  count : Int32,
) -> PianoCanvas =
  #|(host,width,height,count) => {
  #| const doc=host.ownerDocument,ratio=Math.min(doc.defaultView.devicePixelRatio,Math.sqrt(32000000/Math.max(1,width*height))),canvas=doc.createElement('canvas');
  #| canvas.width=Math.ceil(width*ratio);canvas.height=Math.ceil(height*ratio);canvas.style.cssText=`display:block;width:${width}px;height:${height}px;background:#fff`;
  #| canvas.setAttribute('aria-label',`Piano roll with ${count} notes`);canvas.dataset.bdfPianoRoll='';const ctx=canvas.getContext('2d');if(!ctx)throw new Error('Canvas 2D context unavailable');ctx.scale(ratio,ratio);return canvas;
  #|}

///|
extern "js" fn piano_rect(
  canvas : PianoCanvas,
  color : String,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit =
  #|(canvas,color,x,y,width,height) => {const ctx=canvas.getContext('2d');ctx.fillStyle=color;ctx.fillRect(x,y,width,height)}

///|
extern "js" fn piano_error(message : String) -> PianoCanvas =
  #|(message) => {throw new Error(message)}

///|
fn draw_piano_roll(
  host : BrowserHost,
  data : Bytes,
  viewport : Double,
  zoom : Double,
) -> PianoCanvas raise {
  let sequence = @core.parse_smf(data)
  let mut end = 0.0
  let mut count = 0
  for event in sequence.events {
    if event.message is Note(duration~, ..) {
      count += 1
      if event.time + duration > end {
        end = event.time + duration
      }
    }
  }
  let width = piano_width(viewport, end, zoom)
  let canvas = new_piano_canvas(host, width, 128.0 * 12.0 * zoom, count)
  for key in 0..<128 {
    let pitch = key % 12
    let color = if pitch == 1 ||
      pitch == 3 ||
      pitch == 6 ||
      pitch == 8 ||
      pitch == 10 {
      "#f1f1f1"
    } else {
      "#fff"
    }
    piano_rect(
      canvas,
      color,
      0.0,
      (127 - key).to_double() * 12.0 * zoom,
      width,
      12.0 * zoom,
    )
  }
  for event in sequence.events {
    if event.message is Note(key~, duration~, ..) {
      let duration_width = duration * 64.0 * zoom
      let height = 12.0 * zoom - 2.0
      piano_rect(
        canvas,
        "#3569a3",
        event.time * 64.0 * zoom,
        (127 - key).to_double() * 12.0 * zoom + 1.0,
        if duration_width > 2.0 {
          duration_width
        } else {
          2.0
        },
        if height > 2.0 {
          height
        } else {
          2.0
        },
      )
    }
  }
  canvas
}

///|
extern "js" fn install_music_dom(
  host : BrowserHost,
  surface : BrowserHost,
  load : () -> @js_async.Promise[Bytes],
  draw : (Bytes, Double, Double) -> PianoCanvas,
) -> Unit =
  #|(host,surface,load,draw) => {
  #| const key=Symbol.for('f4ah6o.bdf.pageLayout'),state=host[key],oldZoom=state.zoom,oldDispose=state.dispose;
  #| let mode='score',zoom=1,generation=0,canvas,data,loading,disposed=false,scoreZoomDirty=false;
  #| const read=()=>data?Promise.resolve(data):(loading??=Promise.resolve().then(load).then(bytes=>{data=bytes;return bytes}).finally(()=>{loading=undefined}));
  #| const render=async()=>{const current=++generation;const bytes=await read();if(disposed||current!==generation||mode!=='piano-roll')return;const next=draw(bytes,host.clientWidth,zoom);if(disposed||current!==generation||mode!=='piano-roll')return;canvas?.remove();canvas=next;surface.style.display='none';host.append(next)};
  #| const fail=error=>{if(!disposed&&host.dispatchEvent(new host.ownerDocument.defaultView.CustomEvent('error',{detail:error,cancelable:true})))console.error('bdf piano roll:',error)};
  #| state.musicActive=()=>mode==='piano-roll';state.musicMode=async value=>{if(value!=='score'&&value!=='piano-roll')throw new RangeError('unknown music mode');if(value==='score'){if(scoreZoomDirty){oldZoom(zoom);scoreZoomDirty=false}mode=value;generation++;canvas?.remove();canvas=undefined;surface.style.display='';return}mode=value;host[Symbol.for('f4ah6o.bdf.find')]?.clear();surface.style.display='none';await render()};
  #| state.zoom=value=>{if(mode==='piano-roll'){zoom=value;scoreZoomDirty=true;void render().catch(fail)}else{oldZoom(value);zoom=value}};
  #| state.dispose=()=>{disposed=true;generation++;oldDispose()};
  #|}

///|
extern "js" fn piano_active(host : BrowserHost) -> Bool =
  #|(host) => !!host[Symbol.for('f4ah6o.bdf.pageLayout')]?.musicActive?.()

///|
fn install_music_mode(
  host : BrowserHost,
  surface : BrowserHost,
  load : () -> @js_async.Promise[Bytes],
) -> Unit {
  install_music_dom(host, surface, load, (data, width, zoom) => {
    draw_piano_roll(host, data, width, zoom) catch {
      error => piano_error(error.to_string())
    }
  })
}

///|
extern "js" fn set_music_mode(
  host : BrowserHost,
  mode : String,
) -> @js_async.Promise[Unit] =
  #|(host,mode) => {const state=host[Symbol.for('f4ah6o.bdf.pageLayout')],sheet=host[Symbol.for('f4ah6o.bdf.sheet')];if(!state&&!sheet)return Promise.reject(new Error('BDF view is not mounted'));if(mode!=='score'&&mode!=='piano-roll')return Promise.reject(new RangeError('unknown music mode'));return state?.musicMode?state.musicMode(mode):Promise.resolve()}

///|
/// Switch between score pages and the MIDI piano roll. Resolves after rendering.
#export_name("bdf_set_music_mode_async")
pub fn bdf_set_music_mode_async(
  host : BrowserHost,
  mode : String,
) -> @js_async.Promise[Unit] {
  set_music_mode(host, mode)
}
