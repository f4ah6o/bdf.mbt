///|
extern "js" fn install_midi_source(
  host : BrowserHost,
  load : (BrowserMusicOptions) -> @js_async.Promise[BrowserMusicPlayer],
) -> Unit =
  #|(host,load) => {
  #| const state=host[Symbol.for('f4ah6o.bdf.pageLayout')]??host[Symbol.for('f4ah6o.bdf.sheet')],previous=state.dispose,players=new Set();let disposed=false,queue=Promise.resolve();
  #| state.midiPlayer=async options=>{if(disposed)throw new Error('BDF view is not mounted');const job=queue.then(()=>{if(disposed)throw new Error('BDF view is not mounted');return load(options)});queue=job.then(()=>{},()=>{});const player=await job;if(disposed){player.dispose();throw new Error('BDF view is not mounted')}players.add(player);const dispose=player.dispose,play=player.play;player.dispose=()=>{players.delete(player);dispose()};player.play=()=>{if(disposed)throw new Error('BDF view is not mounted');players.add(player);return play()};return player};
  #| state.dispose=()=>{if(disposed)return;disposed=true;for(const player of players)player.dispose();previous()};
  #|}

///|
extern "js" fn music_player_for_view(
  host : BrowserHost,
  options : BrowserMusicOptions,
) -> @js_async.Promise[BrowserMusicPlayer] =
  #|(host,options) => {const state=host[Symbol.for('f4ah6o.bdf.pageLayout')]??host[Symbol.for('f4ah6o.bdf.sheet')];if(!state)return Promise.reject(new Error('BDF view is not mounted'));return state.midiPlayer?state.midiPlayer(options):Promise.resolve(null)}

///|
/// Load a mounted view's MIDI and cues; null means the view has no sequence.
/// The host disposes its players on unmount.
#export_name("bdf_music_player_for_view_async")
pub fn bdf_music_player_for_view_async(
  host : BrowserHost,
  options : BrowserMusicOptions,
) -> @js_async.Promise[BrowserMusicPlayer] {
  music_player_for_view(host, options)
}

///|
extern "js" fn invoke_midi_create(
  create : () -> BrowserMusicPlayer,
) -> @js_async.Promise[BrowserMusicPlayer] =
  #|(create) => Promise.resolve().then(create)

///|
fn install_view_midi(
  host : BrowserHost,
  document : BrowserDocument,
  view : @core.View,
  midi_loader? : (BrowserMusicOptions) -> @js_async.Promise[BrowserMusicPlayer],
) -> Unit {
  if view.play is Some(play) && play.seq is Some(hash) {
    let load = midi_loader.unwrap_or(options => {
      @js_async.Promise::from_async(() => {
        let cues = match play.cues {
          Some(cue_hash) => Some(@core.decode_cues(document.part(cue_hash)))
          None => None
        }
        let bytes = document.part(hash)
        invoke_midi_create(() => {
          bdf_music_player(
            midi_input_from_bytes(bytes),
            audio_cues_from_core(cues),
            options,
          )
        }).wait()
      })
    })
    install_midi_source(host, load)
  }
}
