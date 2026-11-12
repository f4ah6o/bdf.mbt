///|
#external
priv type ViewerConverter

///|
#external
priv type ViewerFileData

///|
#external
priv type ViewerFileOptions

///|
#external
priv type ViewerConversion

///|
extern "js" fn viewer_converter_streams(converter : ViewerConverter) -> Bool =
  #|(converter) => !!(converter.open&&converter.page&&converter.finish&&converter.close)

///|
extern "js" fn viewer_convert(
  converter : ViewerConverter,
  data : ViewerFileData,
  options : ViewerFileOptions,
  streaming : Bool,
) -> @js_async.Promise[ViewerConversion] =
  #|(converter,data,options,streaming) => streaming?converter.open(data,options??{}):converter.convert(data,options??{})

///|
extern "js" fn viewer_conversion_source(
  result : ViewerConversion,
) -> RenderSourceInput =
  #|(result) => ({kind:'buffer',buffer:result.bdf.buffer.slice(result.bdf.byteOffset,result.bdf.byteOffset+result.bdf.byteLength)})

///|
extern "js" fn viewer_conversion_pages(result : ViewerConversion) -> Int32 =
  #|(result) => result.pages??0

///|
extern "js" fn viewer_conversion_has_stream(result : ViewerConversion) -> Bool =
  #|(result) => result.stream!==undefined

///|
extern "js" fn viewer_conversion_stream(result : ViewerConversion) -> Int32 =
  #|(result) => result.stream

///|
extern "js" fn viewer_conversion_page(
  converter : ViewerConverter,
  stream : Int32,
  page : Int32,
) -> @js_async.Promise[ViewerConversion] =
  #|(converter,stream,page) => converter.page(stream,page)

///|
extern "js" fn viewer_conversion_finish(
  converter : ViewerConverter,
  stream : Int32,
) -> @js_async.Promise[ViewerConversion] =
  #|(converter,stream) => converter.finish(stream)

///|
extern "js" fn viewer_conversion_close(
  converter : ViewerConverter,
  stream : Int32,
) -> Unit =
  #|(converter,stream) => {void converter.close?.(stream)?.catch(()=>{})}

///|
extern "js" fn viewer_renderer_add_page(
  renderer : BrowserRenderClient,
  view : String,
  page : Int32,
  result : ViewerConversion,
) -> @js_async.Promise[Unit] =
  #|(renderer,view,page,result) => {const b=result.bdf;return renderer.addPage(view,page,b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength))}

///|
extern "js" fn viewer_renderer_replace(
  renderer : BrowserRenderClient,
  result : ViewerConversion,
) -> @js_async.Promise[RenderValue] =
  #|(renderer,result) => {const b=result.bdf;return renderer.replace({kind:'buffer',buffer:b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength)})}

///|
extern "js" fn viewer_password_none() -> CryptoCredential =
  #|() => undefined

///|
extern "js" fn viewer_progress(
  dom : ViewerDom,
  page : Int32,
  pages : Int32,
) -> Unit =
  #|(dom,page,pages) => dom.api.dispatchEvent(new CustomEvent('conversionprogress',{detail:{page,pages}}))

///|
extern "js" fn viewer_invalidate_page(
  dom : ViewerDom,
  view : String,
  index : Int32,
) -> Unit =
  #|(dom,view,index) => {dom.pageUpdates.add(JSON.stringify([view,index]));if(dom.view?.id!==view)return;const frame=dom.stage.querySelector(`div[data-bdf-page="${index}"]`),canvas=frame?.querySelector('canvas');if(canvas){canvas.dataset.contentRevision=String(Number(canvas.dataset.contentRevision??'0')+1);canvas.dataset.renderRequest=String(Number(canvas.dataset.renderRequest??'0')+1);canvas.dataset.contentUpdating='true';canvas.dataset.loaded='';delete frame.dataset.bdfContentReady;const selection=frame.ownerDocument.getSelection();if(selection?.rangeCount&&!selection.isCollapsed&&selection.getRangeAt(0).intersectsNode(frame))selection.removeAllRanges();frame.querySelector('.bdfTextLayer')?.remove()}}

///|
extern "js" fn viewer_reset_page_updates(dom : ViewerDom) -> Unit =
  #|(dom) => dom.pageUpdates.clear()

///|
extern "js" fn viewer_finish_page_update(
  dom : ViewerDom,
  view : String,
  index : Int32,
) -> Unit =
  #|(dom,view,index) => dom.pageUpdates.delete(JSON.stringify([view,index]))

///|
extern "js" fn viewer_reload_page(
  dom : ViewerDom,
  view : String,
  index : Int32,
  render : (ViewerCanvas) -> Unit,
) -> Unit =
  #|(dom,view,index,render) => {if(dom.view?.id!==view)return;const frame=dom.stage.querySelector(`div[data-bdf-page="${index}"]`),canvas=frame?.querySelector('canvas');if(canvas){canvas.dataset.contentRevision=String(Number(canvas.dataset.contentRevision??'0')+1);canvas.dataset.renderRequest=String(Number(canvas.dataset.renderRequest??'0')+1);canvas.dataset.loaded='';delete canvas.dataset.contentUpdating;delete frame.dataset.bdfContentReady;const selection=frame.ownerDocument.getSelection();if(selection?.rangeCount&&!selection.isCollapsed&&selection.getRangeAt(0).intersectsNode(frame))selection.removeAllRanges();frame.querySelector('.bdfTextLayer')?.remove();const area=dom.stage.getBoundingClientRect(),rect=frame.getBoundingClientRect();if(rect.bottom>=area.top-600&&rect.top<=area.bottom+600)render(canvas);dom.selectionRecheck?.()}}

///|
priv struct ViewerStream {
  converter : ViewerConverter
  id : Int32
}

///|
fn ViewerController::cancel_stream(self : ViewerController) -> Unit {
  viewer_reset_page_updates(self.dom)
  if self.active_stream is Some(stream) {
    self.active_stream = None
    viewer_conversion_close(stream.converter, stream.id)
  }
}

///|
async fn ViewerController::open_file(
  self : ViewerController,
  converter : ViewerConverter,
  data : ViewerFileData,
  options : ViewerFileOptions,
) -> RenderValue {
  let streaming = viewer_converter_streams(converter)
  let result = viewer_remember(
    self.dom,
    viewer_convert(converter, data, options, streaming),
  ).wait()
  let manifest = self.open(
    viewer_conversion_source(result),
    viewer_password_none(),
  )
  let pages = viewer_conversion_pages(result)
  if streaming && pages > 0 && viewer_conversion_has_stream(result) {
    let stream = viewer_conversion_stream(result)
    let serial = self.document_serial
    self.active_stream = Some({ converter, id: stream, })
    viewer_callback_ignore(
      @js_async.Promise::from_async(() => {
        self.fill_pages(
          converter,
          stream,
          pages,
          viewer_raw_first_view(manifest),
          serial,
        )
      }),
    )
  }
  manifest
}

///|
async fn ViewerController::fill_pages(
  self : ViewerController,
  converter : ViewerConverter,
  stream : Int32,
  pages : Int32,
  view_id : String,
  serial : Int32,
) -> Unit {
  if view_id == "" {
    self.cancel_stream()
    return
  }
  defer {
    if self.active_stream is Some(active) && active.id == stream {
      self.active_stream = None
    }
    viewer_conversion_close(converter, stream)
  }
  try {
    for page in 0..<pages {
      if serial != self.document_serial {
        return
      }
      let part = viewer_remember(
        self.dom,
        viewer_conversion_page(converter, stream, page),
      ).wait()
      if serial != self.document_serial {
        return
      }
      viewer_invalidate_page(self.dom, view_id, page)
      try {
        viewer_remember(
          self.dom,
          viewer_renderer_add_page(self.renderer, view_id, page, part),
        ).wait()
      } catch {
        error => {
          if serial == self.document_serial {
            self.reload_stream_page(view_id, page)
          }
          raise error
        }
      }
      if serial != self.document_serial {
        return
      }
      self.find_stale = true
      self.reload_stream_page(view_id, page)
      viewer_progress(self.dom, page, pages)
    }
    if serial != self.document_serial {
      return
    }
    let whole = viewer_remember(
      self.dom,
      viewer_conversion_finish(converter, stream),
    ).wait()
    if serial != self.document_serial {
      return
    }
    let raw = viewer_remember(
      self.dom,
      viewer_renderer_replace(self.renderer, whole),
    ).wait()
    if serial == self.document_serial {
      self.manifest = Some(@core.parse_manifest(viewer_raw_string(raw)))
      viewer_dom_manifest(self.dom, raw)
      if self.current is Some(current) {
        let mut updated : @core.View? = None
        if self.manifest is Some(manifest) {
          for view in manifest.views {
            if view.id == current.id {
              updated = Some(view)
              break
            }
          }
        }
        self.current = updated
        viewer_dom_set_view(self.dom, current.id)
      }
      viewer_dom_event(self.dom, "conversiondone", raw)
      if self.find_hits is Some(_) && self.find_query != "" && self.find_stale {
        let query = self.find_query
        viewer_callback_ignore(
          @js_async.Promise::from_async(() => self.research_background(query)),
        )
      }
    }
  } catch {
    error =>
      if serial == self.document_serial {
        viewer_dom_failure(self.dom, error.to_string())
      } else {
        viewer_forget_error(self.dom, error.to_string())
      }
  }
}

///|
fn ViewerController::reload_stream_page(
  self : ViewerController,
  view_id : String,
  page : Int32,
) -> Unit {
  viewer_finish_page_update(self.dom, view_id, page)
  if self.current is Some(view) && view.id == view_id {
    viewer_reload_page(self.dom, view_id, page, canvas => {
      viewer_callback_ignore(
        @js_async.Promise::from_async(() => {
          self.render_page(view, page, canvas, self.generation)
        }),
      )
    })
  }
}
