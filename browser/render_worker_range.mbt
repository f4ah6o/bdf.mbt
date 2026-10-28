///|
#external
priv type RenderRange

///|
extern "js" fn render_source_range(source : RenderSourceInput) -> Bool =
  #|(source) => source.kind==='single' && !!source.range

///|
extern "js" fn render_range_new(source : RenderSourceInput) -> RenderRange =
  #|(source) => ({url:source.url,whole:undefined})

///|
extern "js" fn render_range_read(
  source : RenderRange,
  offset : Double,
  length : Int32,
) -> @js_async.Promise[Bytes] =
  #|async (source,offset,length) => {
  #| if(!Number.isSafeInteger(offset)||!Number.isSafeInteger(length)||offset<0||length<0||offset>Number.MAX_SAFE_INTEGER-length)throw new Error('bdf: part out of range');
  #| if(!length)return new Uint8Array(0);
  #| if(!source.whole){
  #|   const response=await fetch(source.url,{headers:{Range:'bytes='+offset+'-'+(offset+length-1)}});
  #|   if(response.status===206){const header=response.headers.get('Content-Range');if(header!==null){const match=/^bytes (\d+)-(\d+)\/(?:\d+|\*)$/.exec(header);if(!match||Number(match[1])!==offset||Number(match[2])!==offset+length-1){await response.body?.cancel();throw new Error('bdf: range response does not match the request')}}const data=await self[Symbol.for('f4ah6o.bdf.renderWorker')].read(response,length,'range response');if(data.length!==length)throw new Error('bdf: range response is shorter than its stated size');return data}
  #|   if(response.status!==200)throw new Error('bdf: range request failed with '+response.status);
  #|   if(source.whole)response.body?.cancel().catch(()=>{});else{const whole=self[Symbol.for('f4ah6o.bdf.renderWorker')].read(response,1073741824,'single-file response');source.whole=whole;whole.catch(()=>{if(source.whole===whole)source.whole=undefined})}
  #| }
  #| const data=await source.whole;if(offset>data.length||length>data.length-offset)throw new Error('bdf: part out of range');return data.subarray(offset,offset+length)
  #|}

///|
fn render_range_loader(
  source : RenderRange,
  header : @core.Header,
  manifest : @core.Manifest,
) -> SplitPartLoader {
  make_split_loader((hash, _) => {
    @js_async.Promise::from_async(() => {
      for part in manifest.parts {
        if part.hash == hash {
          let offset = header.manifest_offset.to_double() +
            header.manifest_length.to_double() +
            part.offset.to_double()
          return render_range_read(source, offset, part.length).wait()
        }
      }
      raise BadFormat("unknown part")
    })
  })
}

///|
async fn RenderWorkerState::open_range(
  self : RenderWorkerState,
  request : RenderRequest,
  replace : Bool,
  source : RenderSourceInput,
) -> RenderOutcome {
  let range = render_range_new(source)
  let head = render_range_read(range, 0.0, 32).wait()
  let header = @core.parse_header_prefix(head) catch {
    error => return render_error(error.to_string(), "")
  }
  let stored = render_range_read(
    range,
    header.manifest_offset.to_double(),
    header.manifest_length,
  ).wait()
  let raw = @core.decode_encoded(
    stored,
    if header.manifest_encoding == 1 {
      "deflate-raw"
    } else {
      "identity"
    },
    268435456,
  ) catch {
    error => return render_error(error.to_string(), "")
  }
  let encrypted = render_json_encrypted(raw)
  if (header.flags == 1) != encrypted {
    return render_error("bdf: encryption flag does not match the manifest", "")
  }
  if encrypted {
    if replace {
      return render_error(
        "bdf: the document is encrypted and needs a password", "password-required",
      )
    }
    let text = @utf8.decode(raw) catch {
      _ => return render_error("invalid UTF-8 manifest", "")
    }
    let metadata = @core.parse_encrypted_manifest(text) catch {
      error => return render_error(error.to_string(), "")
    }
    self.locked = Some({
      metadata,
      loader: render_range_loader(range, header, metadata.outer),
    })
    return self.unlock(request)
  }
  let text = @utf8.decode(raw) catch {
    _ => return render_error("invalid UTF-8 manifest", "")
  }
  let manifest = @core.parse_manifest(text) catch {
    error => return render_error(error.to_string(), "")
  }
  let doc = new_render_split(raw, render_range_loader(range, header, manifest)) catch {
    error => return render_error(error.to_string(), "")
  }
  self.install(doc)
  render_success(render_json_value(doc.raw))
}
