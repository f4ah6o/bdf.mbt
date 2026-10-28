///|
// Draw offscreen and publish only the newest completed viewport. Resources
// stay alive until a detached or unmounted host has finished its pending draw.
extern "js" fn start_live_sheet(
  host : BrowserHost,
  sheet_width : Double,
  sheet_height : Double,
  interactive : Bool,
  draw : (CanvasContext, Double, Double, Double, Double, Double) -> @js_async.Promise[
    Unit,
  ],
  publish : (BrowserHost, Double, Double, Double, Double) -> Unit,
  release : () -> Unit,
) -> @js_async.Promise[Int32] =
  #|(host,sheetWidth,sheetHeight,interactive,draw,publish,release) => new Promise((resolve,reject) => {
  #| const doc=host.ownerDocument,win=doc.defaultView,key=Symbol.for('f4ah6o.bdf.sheet');let disposed=false,running=false,first=true,released=false,frame=0,revision=0,mutation,resize,zoom=1;
  #| const oldWidth=host.style.width,oldHeight=host.style.height;let defaultWidth=false,defaultHeight=false;
  #| const releaseOnce=()=>{if(!released){released=true;release()}};
  #| const restoreSize=()=>{if(defaultWidth&&host.style.width==='640px')host.style.width=oldWidth;if(defaultHeight&&host.style.height==='400px')host.style.height=oldHeight};
  #| try {
  #|  if(!host.clientWidth&&!host.style.width){host.style.width='640px';defaultWidth=true}if(!host.clientHeight&&!host.style.height){host.style.height='400px';defaultHeight=true}
  #|  const spacer=doc.createElement('div');spacer.style.cssText='position:relative';const canvas=doc.createElement('canvas');canvas.style.cssText='position:sticky;left:0;top:0;display:block';canvas.setAttribute('aria-label','BDF sheet');canvas.dataset.bdfSheet='';spacer.append(canvas);let content=spacer,clip;if(interactive){clip=doc.createElement('div');clip.style.cssText='position:absolute;left:0;top:0;overflow:hidden;pointer-events:none';content=doc.createElement('div');content.style.cssText='position:absolute;left:0;top:0;width:0;height:0;transform-origin:0 0';clip.append(content);spacer.append(clip)}host.append(spacer);
  #|  const dimensions=()=>{const width=host.clientWidth||parseFloat(host.style.width)||640,height=host.clientHeight||parseFloat(host.style.height)||400,extentWidth=Math.max(width,sheetWidth*zoom),extentHeight=Math.max(height,sheetHeight*zoom);spacer.style.width=extentWidth+'px';spacer.style.height=extentHeight+'px';if(clip){clip.style.width=extentWidth+'px';clip.style.height=extentHeight+'px'}return{width,height}};
  #|  const onerror=error=>{if(first){first=false;record.dispose();if(host[key]===record)delete host[key];const copyKey=Symbol.for('f4ah6o.bdf.copy');host[copyKey]?.dispose();delete host[copyKey];host.replaceChildren();reject(error)}else if(host.dispatchEvent(new win.CustomEvent('error',{detail:error,cancelable:true})))console.error('bdf sheet:',error)};
  #|  const schedule=()=>{if(disposed)return;revision++;if(!running&&!frame)frame=win.requestAnimationFrame(paint)};
  #|  const paint=async()=>{frame=0;if(disposed||running)return;running=true;const current=revision,scale=zoom;try{const {width,height}=dimensions(),dpr=win.devicePixelRatio||1,w=Math.ceil(width*dpr),h=Math.ceil(height*dpr),x=host.scrollLeft,y=host.scrollTop;if(!Number.isFinite(w)||!Number.isFinite(h)||w<=0||h<=0||w>8192||h>8192||w*h>16777216)throw new RangeError('sheet bitmap exceeds browser limits');const scratch=doc.createElement('canvas');scratch.width=w;scratch.height=h;const ctx=scratch.getContext('2d');if(!ctx)throw new Error('Canvas 2D context unavailable');ctx.scale(dpr*scale,dpr*scale);await draw(ctx,x/scale,y/scale,width/scale,height/scale,dpr*scale);if(!disposed&&current===revision){publish(content,x/scale,y/scale,width/scale,height/scale);canvas.width=w;canvas.height=h;canvas.style.width=width+'px';canvas.style.height=height+'px';const target=canvas.getContext('2d');if(!target)throw new Error('Canvas 2D context unavailable');target.drawImage(scratch,0,0);canvas.dataset.bdfSheetViewport=JSON.stringify([x,y,width,height]);canvas.dataset.bdfSheetZoom=String(scale);canvas.dataset.bdfSheetFrame=String(current);if(first){first=false;resolve(1)}}}catch(error){if(!disposed)onerror(error)}finally{running=false;if(disposed)releaseOnce();else if(current!==revision&&!frame)frame=win.requestAnimationFrame(paint)}};
  #|  const record=host[key]={spacer,content,get zoom(){return zoom},setZoom(value){zoom=value;if(interactive)content.style.transform=`scale(${zoom})`;dimensions();host.scrollTo({left:0,top:0,behavior:'instant'});schedule();host[Symbol.for('f4ah6o.bdf.find')]?.refresh()},setLayout(){host.scrollTo({left:0,top:0,behavior:'instant'});schedule();host[Symbol.for('f4ah6o.bdf.find')]?.refresh()},dispose(){if(disposed)return;disposed=true;mutation?.disconnect();resize?.disconnect();host.removeEventListener('scroll',schedule);if(frame)win.cancelAnimationFrame(frame);frame=0;restoreSize();if(first){first=false;reject(new Error('sheet mount cancelled'))}if(!running)releaseOnce()}};
  #|  host.addEventListener('scroll',schedule);if(typeof ResizeObserver==='function'){resize=new ResizeObserver(schedule);resize.observe(host)}
  #|  if(typeof MutationObserver==='function'){const watch=(weak,k,owner,connected)=>{const ob=new MutationObserver(()=>{const h=weak.deref();if(!h){ob.disconnect();return}if(h.isConnected)connected=true;else if(connected){h[k]?.dispose();delete h[k]}});ob.observe(owner,{childList:true,subtree:true});return ob};const weak=typeof WeakRef==='function'?new WeakRef(host):{deref:()=>host};mutation=watch(weak,key,doc,host.isConnected)}
  #|  schedule();
  #| } catch(error){first=false;host[key]?.dispose();delete host[key];const copyKey=Symbol.for('f4ah6o.bdf.copy');host[copyKey]?.dispose();delete host[copyKey];restoreSize();releaseOnce();reject(error)}
  #|})

///|
extern "js" fn sheet_initial_width(host : BrowserHost) -> Double =
  #|(host) => host.clientWidth||parseFloat(host.style.width)||640

///|
extern "js" fn sheet_initial_height(host : BrowserHost) -> Double =
  #|(host) => host.clientHeight||parseFloat(host.style.height)||400

///|
extern "js" fn sheet_initial_scale(host : BrowserHost) -> Double =
  #|(host) => host.ownerDocument.defaultView.devicePixelRatio||1

///|
extern "js" fn order_sheet_layer(
  container : BrowserHost,
  x : Int32,
  y : Int32,
) -> Unit =
  #|(container,x,y) => {const layer=container.lastElementChild;layer.style.pointerEvents='auto';layer.dataset.bdfSheetTile=`${x},${y}`;for(const other of container.querySelectorAll(':scope > [data-bdf-sheet-tile]')){if(other===layer)continue;const [ox,oy]=other.dataset.bdfSheetTile.split(',').map(Number);if(oy>y||(oy===y&&ox>x)){container.insertBefore(layer,other);break}}}

///|
#external
priv type SheetPreparation

///|
extern "js" fn sheet_preparation(
  paint : (Array[@core.Tile]) -> @js_async.Promise[Unit],
  text : (Array[@core.Tile]) -> @js_async.Promise[Unit],
) -> SheetPreparation =
  #|(paint,text) => {let pending=Promise.resolve();return {run(tiles,isText){const result=pending.then(()=>isText?text(tiles):paint(tiles));pending=result.catch(()=>{});return result}}}

///|
extern "js" fn prepare_sheet_tiles(
  preparation : SheetPreparation,
  tiles : Array[@core.Tile],
  text : Bool,
) -> @js_async.Promise[Unit] =
  #|(preparation,tiles,text) => preparation.run(tiles,text)

///|
#external
priv type SheetRecord

///|
extern "js" fn sheet_record(host : BrowserHost) -> SheetRecord =
  #|(host) => host[Symbol.for('f4ah6o.bdf.sheet')]

///|
extern "js" fn current_sheet_record(
  host : BrowserHost,
  record : SheetRecord,
) -> Bool =
  #|(host,record) => host[Symbol.for('f4ah6o.bdf.sheet')]===record

///|
async fn mount_live_sheet(
  host : BrowserHost,
  document : BrowserDocument,
  view : @core.View,
  tiles : Array[@core.Tile],
  resources : BrowserResources,
  prepare : (Array[@core.Tile]) -> @js_async.Promise[Unit],
  load_text : (Array[@core.Tile]) -> @js_async.Promise[Unit],
  load_index : () -> @js_async.Promise[Unit],
  prepare_search : (Array[@core.Tile]) -> @js_async.Promise[Unit],
  interactive~ : Bool = false,
  audio_loader? : (BrowserAudioElement) -> @js_async.Promise[BrowserAudioPlayer],
) -> Int32 {
  let mut handed_off = false
  defer (if !handed_off { dispose_resources(resources) })
  let preparation = sheet_preparation(prepare, prepare_search)
  let request = begin_sheet_request(host)
  defer end_sheet_request(host, request)
  // Prepare the first viewport before replacing an existing mounted document.
  let initial = sheet_viewport(
    0.0,
    0.0,
    sheet_initial_width(host),
    sheet_initial_height(host),
    sheet_initial_scale(host),
  )
  prepare_sheet_tiles(
    preparation,
    visible_sheet_tiles(view, tiles, initial),
    false,
  ).wait()
  if !current_sheet_request(host, request) {
    raise BadFormat("sheet mount superseded")
  }
  clear_host(host)
  reset_host_size(host)
  let (width, height) = @render.sheet_size(view)
  let rendered : Map[String, Bool] = Map([])
  let text_data : Map[String, TextLayerData] = Map([])
  let cell_data = sheet_cell_data(view, tiles)
  let row_axis = sheet_axis(view.rows)
  let col_axis = sheet_axis(view.cols)
  let mut cell_layer_initialized = false
  let mut search_tasks = 0
  let mut released = false
  if interactive {
    install_copy_handler(host)
  }
  let pending = start_live_sheet(
    host,
    width,
    height,
    interactive,
    (ctx, x, y, w, h, scale) => {
      @js_async.Promise::from_async(() => {
        let viewport = sheet_viewport(x, y, w, h, scale)
        let visible = visible_sheet_tiles(view, tiles, viewport)
        prepare_sheet_tiles(preparation, visible, false).wait()
        if interactive {
          for tile in visible {
            let key = tile.x.to_string() + "," + tile.y.to_string()
            if text_data.get(key) is Some(_) {
              continue
            }
            let object = @core.decode_object_resources(
              document.part(tile.object),
            )
            let content = @render.extract_text(object, hash => {
              Some(@core.decode_object_resources(document.part(hash)))
            })
            sheet_remember_cells(cell_data, tile, content)
            let data = new_text_layer_data()
            add_text_node(
              data, "table", -1, 0, -1, -1, 1, 1, "", "", false, 0.0, 0.0, 0.0, 0.0,
            )
            append_text_content(
              data,
              content,
              1,
              0,
              tile_size=view.tile_size,
              sheet_root=true,
            )
            text_data[key] = data
          }
        }
        draw_sheet_region(
          ctx, document, view, visible, viewport, scale, resources,
        )
      })
    },
    (container, x, y, w, h) => {
      if interactive {
        if !cell_layer_initialized {
          initialize_sheet_cells(
            container,
            row_axis.length(),
            col_axis.length(),
            view.frozen_rows,
            view.frozen_cols,
            () => sheet_cells_ready(cell_data),
            () => {
              clear_sheet_cell_metadata(container)
              for part in cell_data.cells.values() {
                for cell in part {
                  if cell.rows > 1 || cell.cols > 1 {
                    add_sheet_cell_metadata(
                      container,
                      cell.row,
                      cell.col,
                      cell.rows,
                      cell.cols,
                    )
                  }
                }
              }
            },
            () => {
              @js_async.Promise::from_async(() => {
                for tile in cell_data.tiles {
                  if !cell_data.cells.contains(sheet_tile_key(tile.x, tile.y)) {
                    if !sheet_container_is_current(host, container) {
                      raise BadFormat("sheet selection cancelled")
                    }
                    load_text([tile]).wait()
                    if !sheet_container_is_current(host, container) {
                      raise BadFormat("sheet selection cancelled")
                    }
                    let object = @core.decode_object_resources(
                      document.part(tile.object),
                    )
                    let content = @render.extract_text(object, hash => {
                      Some(@core.decode_object_resources(document.part(hash)))
                    })
                    sheet_remember_cells(cell_data, tile, content)
                  }
                }
              })
            },
            (r0, c0, r1, c1) => {
              try {
                let value = @render.cell_clipboard(
                  sheet_all_cells(cell_data),
                  { row0: r0, col0: c0, row1: r1, col1: c1, },
                  skip_row=row => row_axis.is_hidden(row),
                  skip_col=col => col_axis.is_hidden(col),
                )
                clipboard_value(value.text, value.html)
              } catch {
                _ => empty_clipboard()
              }
            },
          )
          cell_layer_initialized = true
        }
        let viewport : @render.SheetViewport = { x, y, width: w, height: h, }
        let mut added_layer = false
        for tile in visible_sheet_tiles(view, tiles, viewport) {
          let key = tile.x.to_string() + "," + tile.y.to_string()
          if rendered.get(key) is Some(_) {
            continue
          }
          let data = text_data[key]
          render_text_layer(
            container,
            data,
            tile.x.to_double() * view.tile_size,
            tile.y.to_double() * view.tile_size,
            view.tile_size,
            view.tile_size,
            1.0,
          )
          order_sheet_layer(container, tile.x, tile.y)
          rendered[key] = true
          added_layer = true
        }
        if added_layer {
          refresh_sheet_selection(host)
        }
      }
    },
    () => {
      released = true
      if search_tasks == 0 {
        dispose_resources(resources)
      }
    },
  )
  let record = sheet_record(host)
  handed_off = true
  let result = pending.wait()
  if interactive && current_sheet_record(host, record) {
    install_sheet_find(
      host,
      document,
      view,
      tiles,
      load_text,
      load_index,
      selected => prepare_sheet_tiles(preparation, selected, true),
      () => current_sheet_record(host, record),
      () => search_tasks += 1,
      () => {
        search_tasks -= 1
        if released && search_tasks == 0 {
          dispose_resources(resources)
        }
      },
    )
  }
  if current_sheet_record(host, record) {
    install_view_audio(host, document, view, audio_loader?)
  }
  result
}
