///|
/// A browser Worker implementing the BDF rendering protocol.
#external
pub type BrowserRenderWorker

///|
/// JavaScript client for a rendering Worker.
#external
pub type BrowserRenderClient

///|
extern "js" fn render_client(
  worker : BrowserRenderWorker,
) -> BrowserRenderClient =
  #|(worker) => {
  #| let next=1,terminated=false;const pending=new Map(),images=new Map(),client={worker};
  #| const error=(message,code)=>{const e=new Error(message);e.name='BdfWorkerError';e.code=code;return e};
  #| const svg=async req=>{let result;try{if(typeof document==='undefined'||typeof Image==='undefined')throw new Error('no DOM to draw SVG images with');let image=images.get(req.hash);if(!image){image=(async()=>{const url=URL.createObjectURL(new Blob([req.data],{type:'image/svg+xml'})),img=new Image();img.src=url;try{await img.decode()}finally{URL.revokeObjectURL(url)}return img})();images.set(req.hash,image);image.catch(()=>images.delete(req.hash));if(images.size>32)images.delete(images.keys().next().value)}const img=await image;let bitmap;if(typeof OffscreenCanvas==='function'){const c=new OffscreenCanvas(req.width,req.height);c.getContext('2d').drawImage(img,0,0,req.width,req.height);bitmap=c.transferToImageBitmap()}else{const c=document.createElement('canvas');c.width=req.width;c.height=req.height;c.getContext('2d').drawImage(img,0,0,req.width,req.height);bitmap=await createImageBitmap(c)}result={rid:req.rid,ok:true,bitmap}}catch(e){result={rid:req.rid,ok:false,error:e?.message??String(e)}}worker.postMessage(result,result.ok?[result.bitmap]:[])};
  #| worker.onmessage=event=>{const res=event.data;if(res?.type==='rasterize'){void svg(res);return}const item=pending.get(res?.id);if(!item)return;pending.delete(res.id);if(res.ok)item.resolve(res.result);else item.reject(error(res.error,res.code))};
  #| const call=(request,transfer=[])=>new Promise((resolve,reject)=>{if(terminated){reject(error('render worker terminated'));return}const id=next++;pending.set(id,{resolve,reject});try{worker.postMessage({id,...request},transfer)}catch(e){pending.delete(id);reject(e)}});
  #| client.open=(source,password,options)=>call({type:'open',source,password,options},source.kind==='buffer'?[source.buffer]:[]);client.unlock=password=>call({type:'unlock',password});client.replace=source=>call({type:'replace',source},source.kind==='buffer'?[source.buffer]:[]);client.addPage=(view,page,buffer)=>call({type:'addPage',view,page,buffer},[buffer]);
  #| client.page=(view,page,scale,roles)=>call({type:'page',view,page,scale,roles});client.continuous=(view,viewport,scale)=>call({type:'continuous',view,viewport,scale});client.sheet=(view,viewport,scale)=>call({type:'sheet',view,viewport,scale});
  #| client.text=(view,page)=>call({type:'text',view,page});client.content=(view,page)=>call({type:'content',view,page});client.continuousText=(view,viewport)=>call({type:'continuousText',view,viewport});client.continuousContent=(view,viewport)=>call({type:'continuousContent',view,viewport});client.sheetContent=(view,viewport)=>call({type:'sheetContent',view,viewport});client.search=(view,query,options)=>call({type:'search',view,query,options});client.locate=(view,hits)=>call({type:'locate',view,hits});client.play=view=>call({type:'play',view});client.audio=view=>call({type:'audio',view});client.close=()=>call({type:'close'});
  #| client.terminate=()=>{if(terminated)return;terminated=true;worker.terminate();for(const p of pending.values())p.reject(error('render worker terminated'));pending.clear();images.clear()};return client;
  #|}

///|
/// Connect an existing Worker to the BDF rendering protocol.
#export_name("bdf_render_worker_client")
pub fn bdf_render_worker_client(
  worker : BrowserRenderWorker,
) -> BrowserRenderClient {
  render_client(worker)
}

///|
extern "js" fn new_render_worker(url : String) -> BrowserRenderWorker =
  #|(url) => new Worker(url,{type:'module'})

///|
/// Create a rendering Worker from the compiled `render_worker` executable.
#export_name("bdf_create_render_worker")
pub fn bdf_create_render_worker(url : String) -> BrowserRenderClient {
  render_client(new_render_worker(url))
}
