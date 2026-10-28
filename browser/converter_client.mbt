///|
/// A browser Worker running the BDF converter protocol.
#external
pub type BrowserConverterWorker

///|
/// A converter client with a `ready` promise and streaming methods.
#external
pub type BrowserConverter

///|
extern "js" fn converter_client_error(message : String) -> Int32 =
  #|(message) => {const error=new Error(message);error.name='ConvertError';throw error}

///|
extern "js" fn install_converter_client(
  worker : BrowserConverterWorker,
  wasm_url : String,
  next : () -> Int32,
  complete : (Int32, Bool, String) -> Unit,
  terminate : () -> Unit,
) -> BrowserConverter =
  #|(worker,wasm,next,complete,terminate) => {
  #| const client={worker};let failed,settled=false,resolveReady,rejectReady;const pending=new Map(),error=(message,code)=>{const e=new Error(message);e.name='ConvertError';e.code=code;return e};
  #| client.ready=new Promise((resolve,reject)=>{resolveReady=resolve;rejectReady=reject});
  #| const rejectAll=e=>{failed=e;if(!settled){settled=true;rejectReady(e)}for(const [id,p] of pending){complete(id,false,e.message);p.reject(e)}pending.clear()};
  #| worker.addEventListener('message',event=>{const reply=event.data;if(typeof reply?.id!=='number')return;if(reply.id===0){if(settled)return;settled=true;if(reply.ok)resolveReady(reply.formats??[]);else rejectReady(error(reply.error,reply.code));return}const p=pending.get(reply.id);if(!p)return;pending.delete(reply.id);complete(reply.id,!!reply.ok,reply.error??'');if(reply.ok)p.resolve(reply.result);else p.reject(error(reply.error,reply.code))});
  #| worker.addEventListener('error',event=>rejectAll(error(`converter worker failed: ${event.message}`)));
  #| const call=async request=>{await client.ready;if(failed)throw failed;const id=next();return new Promise((resolve,reject)=>{pending.set(id,{resolve,reject});try{worker.postMessage({id,...request})}catch(e){pending.delete(id);complete(id,false,String(e));reject(e)}})};
  #| const bytes=data=>data instanceof ArrayBuffer?data:data.buffer.slice(data.byteOffset,data.byteOffset+data.byteLength);
  #| client.convert=(data,options={})=>call({type:'convert',data:bytes(data),options});client.open=(data,options={})=>call({type:'open',data:bytes(data),options});client.page=(stream,index)=>call({type:'page',stream,index});client.finish=stream=>call({type:'finish',stream});client.close=stream=>call({type:'close',stream});
  #| client.terminate=()=>{if(failed?.message==='converter terminated')return;terminate();rejectAll(error('converter terminated'));worker.terminate()};
  #| try{worker.postMessage({type:'init',wasm:String(wasm)})}catch(e){rejectAll(error(`converter worker failed: ${e?.message??String(e)}`))}return client;
  #|}

///|
/// Create a client for a Worker running `bdf_install_converter_worker`.
/// `wasm_url` names a converter runtime compatible with the Worker's Go runtime.
#export_name("bdf_converter_client")
pub fn bdf_converter_client(
  worker : BrowserConverterWorker,
  wasm_url : String,
) -> BrowserConverter {
  let state = @convert.Client::new()
  install_converter_client(
    worker,
    wasm_url,
    () => {
      state.request(@convert.Convert, @convert.ConvertOptions::new()).id catch {
        error => converter_client_error(error.to_string())
      }
    },
    (id, ok, error) => {
      ignore(state.reply(id, ok, error)) catch {
        _ => ()
      }
      state.forget(id)
    },
    () => state.terminate(),
  )
}

///|
extern "js" fn new_converter_worker(url : String) -> BrowserConverterWorker =
  #|(url) => new Worker(url,{type:'module'})

///|
/// Create a module Worker and connect it to a converter Wasm runtime.
#export_name("bdf_create_converter")
pub fn bdf_create_converter(
  worker_url : String,
  wasm_url : String,
) -> BrowserConverter {
  bdf_converter_client(new_converter_worker(worker_url), wasm_url)
}
