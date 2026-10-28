///|
extern "js" fn render_worker_transport(
  dispatch : (RenderRequest) -> @js_async.Promise[RenderOutcome],
) -> Unit =
  #|(dispatch) => {
  #| let next=1;const pending=new Map();
  #| const read=async(response,limit,label)=>{const declared=Number(response.headers.get('content-length'));if((!response.headers.get('content-encoding')||response.headers.get('content-encoding')==='identity')&&Number.isFinite(declared)&&declared>limit){await response.body?.cancel();throw new Error(`${label} exceeds limit`)}if(!response.body){const b=new Uint8Array(await response.arrayBuffer());if(b.length>limit)throw new Error(`${label} exceeds limit`);return b}const reader=response.body.getReader(),chunks=[];let size=0;try{for(;;){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>limit){await reader.cancel();throw new Error(`${label} exceeds limit`)}chunks.push(value)}}finally{reader.releaseLock()}const result=new Uint8Array(size);let at=0;for(const chunk of chunks){result.set(chunk,at);at+=chunk.length}return result};
  #| const raster=(hash,data,width,height)=>new Promise((resolve,reject)=>{const rid=next++,timer=setTimeout(()=>{pending.delete(rid);reject(new Error('the page did not draw the SVG image'))},30000);pending.set(rid,{resolve:bitmap=>{clearTimeout(timer);resolve(bitmap)},reject:error=>{clearTimeout(timer);reject(error)}});self.postMessage({type:'rasterize',rid,hash,data,width,height})});
  #| self[Symbol.for('f4ah6o.bdf.renderWorker')]={read,raster};
  #| self.onmessage=event=>{const request=event.data;if(request&&'rid' in request){const p=pending.get(request.rid);pending.delete(request.rid);if(request.ok){if(p)p.resolve(request.bitmap);else request.bitmap.close()}else p?.reject(new Error(request.error));return}Promise.resolve().then(()=>dispatch(request)).then(outcome=>{const response={id:request.id,...outcome},transfer=[];if(outcome.ok){const result=outcome.result;if(typeof ImageBitmap!=='undefined'&&result instanceof ImageBitmap)transfer.push(result);else if(result?.seq instanceof ArrayBuffer)transfer.push(result.seq)}self.postMessage(response,transfer)}).catch(error=>self.postMessage({id:request?.id,ok:false,error:error?.message??String(error),code:error?.code}))};
  #|}

///|
async fn RenderWorkerState::dispatch(
  self : RenderWorkerState,
  request : RenderRequest,
) -> RenderOutcome {
  let kind = render_request_type(request)
  match kind {
    "open" => return self.open_source(request, false)
    "replace" => return self.open_source(request, true)
    "unlock" => return self.unlock(request)
    "close" => {
      self.open = None
      self.locked = None
      return render_success(render_null())
    }
    _ => ()
  }
  guard self.open is Some(document) else {
    return render_error("bdf: no document open", "")
  }
  let view = document.view(render_request_view(request)) catch {
    error => return render_error(error.to_string(), "")
  }
  match kind {
    "addPage" => {
      let index = render_request_page(request)
      if index < 0 || index >= view.pages.length() {
        return render_error(
          "bdf: no page " + index.to_string() + " in view " + view.id,
          "",
        )
      }
      let added = new_render_single(render_request_page_buffer(request)) catch {
        error => return render_error(error.to_string(), "")
      }
      if added.manifest.views.length() != 1 ||
        added.manifest.views[0].pages.length() != 1 {
        return render_error("bdf: not a page document", "")
      }
      for source in added.sources {
        document.sources.push(source)
      }
      view.pages[index] = added.manifest.views[0].pages[0]
      render_success(render_null())
    }
    "page" => render_success(render_page_worker(document, view, request))
    "continuous" =>
      render_success(render_continuous_worker(document, view, request))
    "sheet" => render_success(render_sheet_worker(document, view, request))
    "text" =>
      render_success(render_page_content_worker(document, view, request, true))
    "content" =>
      render_success(render_page_content_worker(document, view, request, false))
    "continuousText" =>
      render_success(
        render_continuous_content_worker(document, view, request, true),
      )
    "continuousContent" =>
      render_success(
        render_continuous_content_worker(document, view, request, false),
      )
    "sheetContent" =>
      render_success(render_sheet_content_worker(document, view, request))
    "search" => render_success(render_search_worker(document, view, request))
    "locate" => render_success(render_locate_worker(document, view, request))
    "play" => render_success(render_play_worker(document, view, false))
    "audio" => render_success(render_play_worker(document, view, true))
    _ => render_error("bdf: unsupported render request " + kind, "")
  }
}

///|
/// Install the BDF rendering protocol in a dedicated Worker.
#export_name("bdf_install_render_worker")
pub fn bdf_install_render_worker() -> Unit {
  let state : RenderWorkerState = { open: None, locked: None, }
  render_worker_transport(request => {
    @js_async.Promise::from_async(() => state.dispatch(request))
  })
}
