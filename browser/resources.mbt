///|
#external
priv type BrowserResources

///|
extern "js" fn new_resources() -> BrowserResources =
  #|() => ({ images: new Map(), fonts: new Map(), decodedBytes: 0 })

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
  #|  if (size && size[0]*size[1] > 2**28) { r.images.set(hash,null); return; }
  #|  const utf16 = b[0]===0xff&&b[1]===0xfe ? "utf-16le" : b[0]===0xfe&&b[1]===0xff ? "utf-16be" : "utf-8";
  #|  const svg = new TextDecoder(utf16).decode(b.subarray(0,512)).replace(/^\ufeff/,"").trimStart().startsWith("<");
  #|  let image;
  #|  if (svg) {
  #|    const url=URL.createObjectURL(new Blob([b],{type:"image/svg+xml"}));
  #|    try { image=new Image(); image.src=url; await image.decode(); } finally { URL.revokeObjectURL(url); }
  #|  } else {
  #|    image=await createImageBitmap(new Blob([b]));
  #|    if (image.width*image.height > 2**28) { image.close(); image=null; }
  #|  }
  #|  if (image) {
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
  #|  const face = new FontFace("bdf-"+hash, bytes);
  #|  await face.load();
  #|  document.fonts.add(face);
  #|  r.fonts.set(hash, face);
  #|}

///|
extern "js" fn dispose_resources(resources : BrowserResources) -> Unit =
  #|(r) => {
  #|  for (const image of r.images.values()) if (image && typeof image.close === "function") image.close();
  #|  for (const face of r.fonts.values()) document.fonts.delete(face);
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
  #|  const img=r.images.get(hash); if (!img) return;
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
  #|  const img=r.images.get(hash);
  #|  let paint="rgba(0,0,0,0)";
  #|  if (img) {
  #|    paint=ctx.createPattern(img,["repeat","repeat-x","repeat-y","no-repeat"][repeat] ?? "repeat");
  #|    if (!paint) throw new Error("cannot create image pattern");
  #|    if (!(m[0]===1 && m[1]===0 && m[2]===0 && m[3]===1 && m[4]===0 && m[5]===0)) paint.setTransform(new DOMMatrix(m));
  #|  }
  #|  if (stroke) ctx.strokeStyle=paint; else ctx.fillStyle=paint;
  #|}
