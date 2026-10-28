///|
#external
priv type ConverterRequest

///|
#external
priv type ConverterRuntime

///|
#external
priv type ConverterStream

///|
#external
priv type ConverterOutcome

///|
#external
priv type ConverterValue

///|
extern "js" fn converter_request_type(request : ConverterRequest) -> String =
  #|(request) => String(request.type)

///|
extern "js" fn converter_request_stream(request : ConverterRequest) -> Int32 =
  #|(request) => Number(request.stream)

///|
extern "js" fn converter_stream_name(request : ConverterRequest) -> String =
  #|(request) => String(request.stream)

///|
extern "js" fn converter_ok(outcome : ConverterOutcome) -> Bool =
  #|(outcome) => outcome.ok

///|
extern "js" fn converter_outcome_runtime(
  outcome : ConverterOutcome,
) -> ConverterRuntime =
  #|(outcome) => outcome.result

///|
extern "js" fn converter_outcome_value(
  outcome : ConverterOutcome,
) -> ConverterValue =
  #|(outcome) => outcome.result

///|
extern "js" fn converter_value_has_stream(value : ConverterValue) -> Bool =
  #|(value) => !!value.stream

///|
extern "js" fn converter_value_stream(
  value : ConverterValue,
) -> ConverterStream =
  #|(value) => value.stream

///|
extern "js" fn converter_open_value(
  value : ConverterValue,
  id : Int32,
) -> ConverterValue =
  #|(value,id) => {const {stream,...opened}=value;return stream?{...opened,stream:id}:opened}

///|
extern "js" fn converter_null_value() -> ConverterValue =
  #|() => null

///|
// The host supplies the compiler-matched Go/TinyGo runtime in the Worker.
// All failures are carried as data so the JavaScript error code is preserved.
extern "js" fn converter_start(
  request : ConverterRequest,
) -> @js_async.Promise[ConverterOutcome] =
  #|async (request) => {try{const go=new globalThis.Go(),response=await fetch(String(request.wasm));if(!response.ok)throw new Error(`wasm fetch failed: ${response.status}`);const {instance}=await WebAssembly.instantiate(await response.arrayBuffer(),go.importObject);let failure;go.run(instance).catch(error=>{failure=error});if(!globalThis.bdfConverter){await new Promise(resolve=>setTimeout(resolve,0));throw new Error(`wasm did not start${failure?`: ${failure}`:''}`)}const result=globalThis.bdfConverter;delete globalThis.bdfConverter;return {ok:true,result}}catch(e){return {ok:false,error:e?.message??String(e),code:e?.code}}}

///|
extern "js" fn converter_invoke(
  runtime : ConverterRuntime,
  request : ConverterRequest,
) -> @js_async.Promise[ConverterOutcome] =
  #|async (runtime,request) => {try{const bytes=new Uint8Array(request.data);const result=await runtime[request.type](bytes,request.options);return {ok:true,result}}catch(e){return {ok:false,error:e?.message??String(e),code:e?.code}}}

///|
extern "js" fn converter_stream_invoke(
  stream : ConverterStream,
  request : ConverterRequest,
) -> @js_async.Promise[ConverterOutcome] =
  #|async (stream,request) => {try{let result;if(request.type==='page')result=await stream.page(Number(request.index));else if(request.type==='finish')result=await stream.finish();else{stream.close();result=null}return {ok:true,result}}catch(e){return {ok:false,error:e?.message??String(e),code:e?.code}}}

///|
extern "js" fn converter_reply_failure(
  request : ConverterRequest,
  outcome : ConverterOutcome,
) -> Unit =
  #|(request,outcome) => {const id=request.type==='init'?0:Number(request.id);self.postMessage({id,ok:false,error:outcome.error,code:outcome.code})}

///|
extern "js" fn converter_reply_error(
  request : ConverterRequest,
  message : String,
) -> Unit =
  #|(request,error) => {const id=request.type==='init'?0:Number(request.id);self.postMessage({id,ok:false,error})}

///|
extern "js" fn converter_reply_formats(
  request : ConverterRequest,
  runtime : ConverterRuntime,
) -> Unit =
  #|(request,runtime) => self.postMessage({id:0,ok:true,formats:runtime.formats})

///|
extern "js" fn converter_reply_value(
  request : ConverterRequest,
  result : ConverterValue,
) -> Unit =
  #|(request,result) => {const id=Number(request.id);try{const transfer=[];if(result&&typeof result==='object'&&'bdf' in result)transfer.push(result.bdf.buffer);self.postMessage({id,ok:true,result},transfer)}catch(e){self.postMessage({id,ok:false,error:e?.message??String(e),code:e?.code})}}

///|
priv struct ConverterWorkerState {
  mut runtime : ConverterRuntime?
  streams : Map[Int32, ConverterStream]
  mut next_stream : Int32
}

///|
async fn ConverterWorkerState::dispatch(
  self : ConverterWorkerState,
  request : ConverterRequest,
) -> Unit {
  let kind = converter_request_type(request)
  if kind == "init" {
    let outcome = converter_start(request).wait()
    if converter_ok(outcome) {
      let runtime = converter_outcome_runtime(outcome)
      self.runtime = Some(runtime)
      converter_reply_formats(request, runtime)
    } else {
      converter_reply_failure(request, outcome)
    }
    return
  }
  guard self.runtime is Some(runtime) else {
    converter_reply_error(request, "converter is not ready")
    return
  }
  match kind {
    "convert" | "open" => {
      let outcome = converter_invoke(runtime, request).wait()
      if !converter_ok(outcome) {
        converter_reply_failure(request, outcome)
        return
      }
      let value = converter_outcome_value(outcome)
      if kind == "open" {
        let mut id = 0
        if converter_value_has_stream(value) {
          id = self.next_stream
          self.next_stream += 1
          self.streams[id] = converter_value_stream(value)
        }
        converter_reply_value(request, converter_open_value(value, id))
      } else {
        converter_reply_value(request, value)
      }
    }
    "page" | "finish" | "close" => {
      let id = converter_request_stream(request)
      match self.streams.get(id) {
        Some(stream) => {
          let outcome = converter_stream_invoke(stream, request).wait()
          if !converter_ok(outcome) {
            converter_reply_failure(request, outcome)
            return
          }
          if kind == "close" {
            self.streams.remove(id)
          }
          converter_reply_value(request, converter_outcome_value(outcome))
        }
        None =>
          if kind == "close" {
            converter_reply_value(request, converter_null_value())
          } else {
            converter_reply_error(
              request,
              "no conversion " + converter_stream_name(request),
            )
          }
      }
    }
    _ => converter_reply_error(request, "unknown request " + kind)
  }
}

///|
extern "js" fn install_converter_listener(
  dispatch : (ConverterRequest) -> @js_async.Promise[Unit],
) -> Unit =
  #|(dispatch) => {self.onmessage=event=>{const request=event.data;Promise.resolve().then(()=>dispatch(request)).catch(e=>{const id=request?.type==='init'?0:Number(request?.id);self.postMessage({id,ok:false,error:e?.message??String(e),code:e?.code})})}}

///|
/// Install the converter protocol in a Worker after loading the matching Go runtime.
#export_name("bdf_install_converter_worker")
pub fn bdf_install_converter_worker() -> Unit {
  let state : ConverterWorkerState = {
    runtime: None,
    streams: {},
    next_stream: 1,
  }
  install_converter_listener(request => {
    @js_async.Promise::from_async(() => state.dispatch(request))
  })
}
