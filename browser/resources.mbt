///|
#external
priv type BrowserResources

///|
extern "js" fn new_resources() -> BrowserResources =
  #|() => ({ images: new Map(), fonts: new Map(), decodedBytes: 0, misses: new Map(),
  #| raster(vec,scale){
  #|   const k=Math.min(Math.max(scale,1/Math.min(vec.width,vec.height)),Math.sqrt(16777216/(vec.width*vec.height)));
  #|   const i=vec.rasters.findIndex(r=>r.k>=k&&r.k<=k*1.25);
  #|   if(i>=0){const [r]=vec.rasters.splice(i,1);vec.rasters.push(r);return r.canvas}
  #|   if(vec.worker){if(!vec.failed.has(k))this.misses.set(`${vec.hash}:${k}`,{vec,k});let best;for(const r of vec.rasters)if(!best||Math.abs(Math.log(r.k/k))<Math.abs(Math.log(best.k/k)))best=r;return best?.canvas}
  #|   const canvas=typeof OffscreenCanvas==='function'?new OffscreenCanvas(Math.max(1,Math.round(vec.width*k)),Math.max(1,Math.round(vec.height*k))):document.createElement('canvas');
  #|   canvas.width=Math.max(1,Math.round(vec.width*k));canvas.height=Math.max(1,Math.round(vec.height*k));canvas.getContext('2d').drawImage(vec.image,0,0,canvas.width,canvas.height);
  #|   vec.rasters.push({k,canvas});if(vec.rasters.length>4){const old=vec.rasters.shift().canvas;old.width=old.height=0}return canvas;
  #| } })

///|
extern "js" fn has_image(resources : BrowserResources, hash : String) -> Bool =
  #|(r, h) => r.images.has(h)

///|
extern "js" fn has_font(resources : BrowserResources, hash : String) -> Bool =
  #|(r, h) => r.fonts.has(h)

///|
// Size checks for formats that expose their pixel dimensions in the header.
// Unknown sizes are left to the browser decoder, as in the upstream renderer.
extern "js" fn load_image(
  resources : BrowserResources,
  hash : String,
  bytes : Bytes,
) -> @js_async.Promise[Unit] =
  #|async (r, hash, b) => {
  #|  const tag = (at, s) => at + s.length <= b.length && [...s].every((c,i) => b[at+i] === c.charCodeAt(0));
  #|  const d = new DataView(b.buffer, b.byteOffset, b.byteLength);
  #|  let size;
  #|  if (tag(0, "\x89PNG\r\n\x1a\n") && b.length >= 24 && tag(12, "IHDR")) size = [d.getUint32(16),d.getUint32(20)];
  #|  else if ((tag(0,"GIF87a") || tag(0,"GIF89a")) && b.length >= 10) size = [d.getUint16(6,true),d.getUint16(8,true)];
  #|  else if (tag(0,"BM") && b.length >= 26) size = d.getUint32(14,true) === 12 ? [d.getUint16(18,true),d.getUint16(20,true)] : [Math.abs(d.getInt32(18,true)),Math.abs(d.getInt32(22,true))];
  #|  else if (tag(0,"RIFF") && tag(8,"WEBP") && b.length >= 30) {
  #|    if (tag(12,"VP8X")) size = [1+(b[24]|b[25]<<8|b[26]<<16),1+(b[27]|b[28]<<8|b[29]<<16)];
  #|    else if (tag(12,"VP8 ")) size = [d.getUint16(26,true)&0x3fff,d.getUint16(28,true)&0x3fff];
  #|    else if (tag(12,"VP8L")) { const v=d.getUint32(21,true); size=[1+(v&0x3fff),1+((v>>>14)&0x3fff)]; }
  #|  } else if (b[0]===0xff && b[1]===0xd8) {
  #|    for (let at=2; at+4<=b.length;) {
  #|      if (b[at]!==0xff) break;
  #|      const m=b[at+1]; if(m===0xff){at++;continue;} if(m===1||(m>=0xd0&&m<=0xd8)){at+=2;continue;}
  #|      if(m===0xd9||m===0xda) break;
  #|      if(m>=0xc0&&m<=0xcf&&m!==0xc4&&m!==0xc8&&m!==0xcc){if(at+9<=b.length) size=[d.getUint16(at+7),d.getUint16(at+5)];break;}
  #|      const n=d.getUint16(at+2); if(n<2) break; at+=2+n;
  #|    }
  #|  }
  #|  const utf16 = b[0]===0xff&&b[1]===0xfe ? "utf-16le" : b[0]===0xfe&&b[1]===0xff ? "utf-16be" : "utf-8";
  #|  const svg = new TextDecoder(utf16).decode(b.subarray(0,512)).replace(/^\ufeff/,"").trimStart().startsWith("<");
  #|  const cache=r.worker;
  #|  if(!svg&&cache){
  #|    if(cache.refused.has(hash)){r.images.set(hash,null);return}
  #|    let bmp=cache.images.get(hash);const stated=bmp?[bmp.width,bmp.height]:size;
  #|    if(stated&&stated[0]*stated[1]>cache.maxPixels){cache.refused.add(hash);r.images.set(hash,null);console.warn(`bdf: image ${hash} of ${stated[0]} × ${stated[1]} pixels is not drawn`);return}
  #|    const held=r.hold.images.has(hash);r.hold.images.add(hash);
  #|    // A string survives the MoonBit async boundary without an extra Error prefix.
  #|    const pin=dimensions=>{r.hold.bytes+=dimensions[0]*dimensions[1]*4;if(r.hold.bytes>cache.holdLimit)throw `bdf: the images of a render take more than ${cache.holdLimit} bytes`};
  #|    if(!held&&stated)pin(stated);
  #|    if(bmp){cache.images.delete(hash);cache.images.set(hash,bmp);r.images.set(hash,bmp);return}
  #|    let pending=cache.decoding.get(hash);
  #|    if(!pending){pending=createImageBitmap(new Blob([b])).then(image=>{if(cache.disposed){image.close();return}if(image.width*image.height>cache.maxPixels){cache.refused.add(hash);console.warn(`bdf: image ${hash} of ${image.width} × ${image.height} pixels is not drawn`);image.close();return}cache.images.set(hash,image);cache.bytes+=image.width*image.height*4;cache.trim()}).finally(()=>cache.decoding.delete(hash));cache.decoding.set(hash,pending)}
  #|    await pending;bmp=cache.images.get(hash);if(!held&&!stated&&bmp)pin([bmp.width,bmp.height]);r.images.set(hash,bmp??null);return;
  #|  }
  #|  if (!svg && size && size[0]*size[1] > 2**28) { r.images.set(hash,null); return; }
  #|  let image;
  #|  if (svg) {
  #|    if(cache?.vectors.has(hash)){r.images.set(hash,cache.vectors.get(hash));return}
  #|    const head=new TextDecoder(utf16).decode(b.subarray(0,65536)),tag=/<(?:[\w.-]+:)?svg\b[^<>]*>/.exec(head)?.[0]??'';
  #|    const attr=name=>{const m=new RegExp(`\\s${name}\\s*=\\s*(?:"([^"]*)"|'([^']*)')`).exec(tag);return m?m[1]??m[2]:undefined};
  #|    const units={'':1,px:1,pt:96/72,pc:16,in:96,cm:96/2.54,mm:96/25.4,q:96/101.6,em:16,ex:8};
  #|    const length=s=>{const m=/^\s*([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)\s*([A-Za-z%]*)\s*$/.exec(s??'');const n=m?Number(m[1])*(units[m[2].toLowerCase()]??NaN):NaN;return n>0?n:undefined};
  #|    let width=length(attr('width')),height=length(attr('height'));const vb=(attr('viewBox')??'').split(/[\s,]+/).filter(Boolean).map(Number),vw=vb.length===4&&vb[2]>0&&vb[3]>0?vb[2]:0,vh=vw?vb[3]:0;
  #|    if(width===undefined||height===undefined){if(width!==undefined&&vw)height=width*vh/vw;else if(height!==undefined&&vw)width=height*vw/vh;else if(vw)[width,height]=[vw,vh];width??=300;height??=150}
  #|    if(r.svgRaster){image={vector:true,worker:true,hash,data:b.slice(),width,height,rasters:[],failed:new Set(),pending:new Map(),disposed:false};if(cache)cache.vectors.set(hash,image);}
  #|    else {const url=URL.createObjectURL(new Blob([b],{type:"image/svg+xml"}));try{image=new Image();image.src=url;await image.decode()}finally{URL.revokeObjectURL(url)}image={vector:true,image,width,height,rasters:[]};}
  #|  } else {
  #|    image=await createImageBitmap(new Blob([b]));
  #|    if (image.width*image.height > 2**28) { image.close(); image=null; }
  #|  }
  #|  if (image && !cache) {
  #|    const width=image.width || image.naturalWidth || 0, height=image.height || image.naturalHeight || 0;
  #|    const bytes=width*height*4;
  #|    if (r.decodedBytes + bytes > 4 * 1024 * 1024 * 1024) {
  #|      if (typeof image.close === "function") image.close();
  #|      throw new RangeError("decoded images exceed render limit");
  #|    }
  #|    r.decodedBytes += bytes;
  #|  }
  #|  r.images.set(hash,image);
  #|}

///|
extern "js" fn load_font(
  resources : BrowserResources,
  hash : String,
  bytes : Bytes,
) -> @js_async.Promise[Unit] =
  #|async (r, hash, bytes) => {
  #|  const cache=r.worker;
  #|  if(cache?.fonts.has(hash))return;
  #|  const load=async()=>{const face=new FontFace("bdf-"+hash,bytes);await face.load();if(cache?.disposed)return;(globalThis.document?.fonts??globalThis.fonts)?.add(face);r.fonts.set(hash,face)};
  #|  if(!cache){await load();return}
  #|  let pending=cache.fontLoading.get(hash);if(!pending){pending=load().finally(()=>cache.fontLoading.delete(hash));cache.fontLoading.set(hash,pending)}await pending;
  #|}

///|
extern "js" fn dispose_resources(resources : BrowserResources) -> Unit =
  #|(r) => {
  #|  if(r.worker){r.worker.holds.delete(r.hold);r.worker.trim();r.images.clear();return}
  #|  for (const image of r.images.values()) if(image?.vector){for(const raster of image.rasters){if(typeof raster.canvas.close==='function')raster.canvas.close();else raster.canvas.width=raster.canvas.height=0}image.rasters.length=0}else if (image && typeof image.close === "function") image.close();
  #|  for (const face of r.fonts.values()) (globalThis.document?.fonts??globalThis.fonts)?.delete(face);
  #|  r.images.clear(); r.fonts.clear();
  #|}

///|
extern "js" fn render_image(
  ctx : CanvasContext,
  resources : BrowserResources,
  hash : String,
  sx : Double,
  sy : Double,
  sw : Double,
  sh : Double,
  dx : Double,
  dy : Double,
  dw : Double,
  dh : Double,
  sub : Bool,
) -> Unit =
  #|(ctx, r, hash, sx, sy, sw, sh, dx, dy, dw, dh, sub) => {
  #|  let img=r.images.get(hash); if (!img) return;
  #|  if(img.vector){const vec=img,t=ctx.getTransform(),x=sub?dw/sw:dw/vec.width,y=sub?dh/sh:dh/vec.height,scale=Math.max(Math.hypot(t.a,t.b)*Math.abs(x),Math.hypot(t.c,t.d)*Math.abs(y))||1;img=r.raster(vec,scale);if(!img)return;if(sub){const kx=img.width/vec.width,ky=img.height/vec.height;sx*=kx;sw*=kx;sy*=ky;sh*=ky}}
  #|  if (sub) ctx.drawImage(img,sx,sy,sw,sh,dx,dy,dw,dh); else ctx.drawImage(img,dx,dy,dw,dh);
  #|}

///|
extern "js" fn render_pattern(
  ctx : CanvasContext,
  resources : BrowserResources,
  hash : String,
  repeat : Int32,
  matrix : FixedArray[Double],
  stroke : Bool,
) -> Unit =
  #|(ctx, r, hash, repeat, m, stroke) => {
  #|  let img=r.images.get(hash),kx=1,ky=1;
  #|  if(img?.vector){const vec=img,t=ctx.getTransform(),a=t.a*m[0]+t.c*m[1],b=t.b*m[0]+t.d*m[1],c=t.a*m[2]+t.c*m[3],d=t.b*m[2]+t.d*m[3];img=r.raster(vec,Math.max(Math.hypot(a,b),Math.hypot(c,d))||1);if(img){kx=img.width/vec.width;ky=img.height/vec.height}}
  #|  let paint="rgba(0,0,0,0)";
  #|  if (img) {
  #|    paint=ctx.createPattern(img,["repeat","repeat-x","repeat-y","no-repeat"][repeat] ?? "repeat");
  #|    if (!paint) throw new Error("cannot create image pattern");
  #|    if (!(m[0]===1 && m[1]===0 && m[2]===0 && m[3]===1 && m[4]===0 && m[5]===0 && kx===1 && ky===1)) paint.setTransform(new DOMMatrix(m).scale(1/kx,1/ky));
  #|  }
  #|  if (stroke) ctx.strokeStyle=paint; else ctx.fillStyle=paint;
  #|}

///|
extern "js" fn worker_resource_rasterizer(resources : BrowserResources) -> Unit =
  #|(r) => {r.svgRaster=self[Symbol.for('f4ah6o.bdf.renderWorker')].raster}

///|
// Resolve the SVG sizes missed during a render; the caller then redraws.
extern "js" fn settle_worker_rasters(
  resources : BrowserResources,
) -> @js_async.Promise[Bool] =
  #|async (r) => {const jobs=[...r.misses.values()];r.misses.clear();const results=await Promise.all(jobs.map(async({vec,k})=>{if(vec.rasters.some(x=>x.k===k))return true;let pending=vec.pending.get(k);if(!pending){pending=(async()=>{try{const w=Math.max(1,Math.round(vec.width*k)),h=Math.max(1,Math.round(vec.height*k)),canvas=await r.svgRaster(vec.hash,vec.data,w,h);if(vec.disposed){canvas.close();return false}vec.rasters.push({k,canvas});while(vec.rasters.length>4)vec.rasters.shift().canvas.close();return true}catch(e){vec.failed.add(k);console.warn(`bdf: SVG image ${vec.hash}: ${e?.message??e}`);return false}finally{vec.pending.delete(k)}})();vec.pending.set(k,pending)}return pending}));return results.some(Boolean)}
