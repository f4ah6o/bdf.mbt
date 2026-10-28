///|
// Install a queue before loading wasm_exec.js so an early init is never lost.
extern "js" fn start_worker(install : () -> Unit) -> Unit =
  #|(install) => {
  #| const waiting=[],url=new URL(self.location.href),runtime=url.searchParams.get('runtime');
  #| self.onmessage=event=>waiting.push(event);
  #| const fail=error=>{const send=event=>{const id=event.data?.type==='init'?0:Number(event.data?.id);self.postMessage({id,ok:false,error:error?.message??String(error),code:error?.code})};self.onmessage=send;for(const event of waiting)send(event)};
  #| if(!runtime){fail(new Error('converter worker requires a runtime URL'));return}
  #| import(new URL(runtime,url).href).then(()=>{install();for(const event of waiting)self.onmessage(event)}).catch(fail);
  #|}

///|
fn main {
  start_worker(() => @browser.bdf_install_converter_worker())
}
