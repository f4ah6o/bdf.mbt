///|
#external
priv type CanvasGroup

///|
#external
priv type CanvasMask

///|
extern "js" fn null_group() -> CanvasGroup =
  #|() => null

///|
extern "js" fn group_begin(
  ctx : CanvasContext,
  alpha : Double,
  blend : Int32,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> CanvasGroup =
  #|(ctx, alpha, blend, x, y, w, h) => {
  #|  const m=ctx.getTransform();
  #|  const pts=[[x,y],[x+w,y],[x,y+h],[x+w,y+h]].map(([px,py])=>[m.a*px+m.c*py+m.e,m.b*px+m.d*py+m.f]);
  #|  let x0=Math.floor(Math.min(...pts.map(p=>p[0]))), y0=Math.floor(Math.min(...pts.map(p=>p[1])));
  #|  let x1=Math.ceil(Math.max(...pts.map(p=>p[0]))), y1=Math.ceil(Math.max(...pts.map(p=>p[1])));
  #|  let reach=Math.max(Math.abs(ctx.shadowOffsetX),Math.abs(ctx.shadowOffsetY))+1.5*ctx.shadowBlur;
  #|  if (ctx.filter && ctx.filter!=="none") for(const n of ctx.filter.matchAll(/-?\d*\.?\d+/g)) reach+=3*Math.abs(Number(n[0]));
  #|  reach=Number.isFinite(reach)?Math.min(Math.ceil(reach),4096):4096;
  #|  if (ctx.canvas && typeof ctx.canvas.width==="number" && typeof ctx.canvas.height==="number") {
  #|    x0=Math.max(x0,-reach);y0=Math.max(y0,-reach);x1=Math.min(x1,ctx.canvas.width+reach);y1=Math.min(y1,ctx.canvas.height+reach);
  #|  }
  #|  const cw=Math.max(1,x1-x0), ch=Math.max(1,y1-y0);
  #|  const canvas=typeof OffscreenCanvas!=="undefined"?new OffscreenCanvas(cw,ch):Object.assign(document.createElement("canvas"),{width:cw,height:ch});
  #|  const next=canvas.getContext("2d"); if(!next) throw new Error("Canvas 2D context unavailable");
  #|  next.setTransform(m.a,m.b,m.c,m.d,m.e-x0,m.f-y0);
  #|  next.font=ctx.font;next.fillStyle=ctx.fillStyle;next.strokeStyle=ctx.strokeStyle;next.lineWidth=ctx.lineWidth;
  #|  return {parent:ctx,canvas,ctx:next,alpha,blend,x:x0,y:y0};
  #|}

///|
extern "js" fn group_context(group : CanvasGroup) -> CanvasContext =
  #|(g) => g.ctx

///|
extern "js" fn group_finish(group : CanvasGroup) -> CanvasContext =
  #|(g) => {
  #|  const ctx=g.parent;
  #|  const names=["source-over","multiply","screen","overlay","darken","lighten","color-dodge","color-burn","hard-light","soft-light","difference","exclusion","hue","saturation","color","luminosity","destination-over","destination-in","destination-out","source-in","source-out","source-atop","destination-atop","xor","copy","lighter"];
  #|  ctx.save();ctx.setTransform(1,0,0,1,0,0);ctx.globalAlpha=g.alpha;ctx.globalCompositeOperation=names[g.blend]??"source-over";
  #|  ctx.drawImage(g.canvas,g.x,g.y);ctx.restore();g.canvas.width=g.canvas.height=0;return ctx;
  #|}

///|
extern "js" fn mask_begin(
  ctx : CanvasContext,
  group : CanvasGroup,
  kind : Int32,
  backdrop : Int32,
  transfer : Bytes,
) -> CanvasMask =
  #|(ctx,g,kind,backdrop,transfer) => {
  #|  const w=g?.canvas.width??1,h=g?.canvas.height??1;
  #|  const canvas=typeof OffscreenCanvas!=="undefined"?new OffscreenCanvas(w,h):Object.assign(document.createElement("canvas"),{width:w,height:h});
  #|  const mc=canvas.getContext("2d");if(!mc) throw new Error("Canvas 2D context unavailable");
  #|  if(kind===1){const n=backdrop>>>0;mc.fillStyle=`rgb(${n>>>24},${(n>>>16)&255},${(n>>>8)&255})`;mc.fillRect(0,0,w,h);}
  #|  mc.fillStyle="#000000";mc.strokeStyle="#000000";mc.lineWidth=1;mc.setTransform(ctx.getTransform());mc.save();
  #|  return {parent:ctx,canvas,ctx:mc,kind,transfer,group:g};
  #|}

///|
extern "js" fn mask_context(mask : CanvasMask) -> CanvasContext =
  #|(m) => m.ctx

///|
extern "js" fn mask_finish(
  mask : CanvasMask,
  current : CanvasGroup,
) -> CanvasContext =
  #|(m,g) => {
  #|  if(!g || m.group!==g){m.canvas.width=m.canvas.height=0;return m.parent;}
  #|  const mc=m.ctx,canvas=m.canvas,w=canvas.width,h=canvas.height;mc.restore();
  #|  const lum=m.kind===1,tr=m.transfer.length===256?m.transfer:null;
  #|  if((lum||tr)&&w>0&&h>0){const image=mc.getImageData(0,0,w,h),d=image.data;
  #|    for(let i=0;i<d.length;i+=4){let v=lum?Math.round(0.3*d[i]+0.59*d[i+1]+0.11*d[i+2]):d[i+3];if(tr)v=tr[v];d[i+3]=v;d[i]=d[i+1]=d[i+2]=0;}mc.putImageData(image,0,0);}
  #|  mc.save();mc.setTransform(1,0,0,1,0,0);mc.globalAlpha=1;mc.globalCompositeOperation="source-in";mc.drawImage(g.canvas,0,0);mc.restore();
  #|  g.canvas.width=g.canvas.height=0;g.canvas=canvas;return m.parent;
  #|}

///|
priv struct CanvasState {
  mut ctx : CanvasContext
  groups : Array[CanvasGroup]
  masks : Array[CanvasMask]
}

///|
fn CanvasState::current_group(self : CanvasState) -> CanvasGroup {
  if self.groups.length() == 0 {
    null_group()
  } else {
    self.groups[self.groups.length() - 1]
  }
}

///|
fn CanvasState::start_group(
  self : CanvasState,
  alpha : Double,
  blend : Int32,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit raise {
  if self.groups.length() + self.masks.length() >= 64 {
    raise BadFormat("groups nested too deep")
  }
  let group = group_begin(self.ctx, alpha, blend, x, y, w, h)
  self.groups.push(group)
  self.ctx = group_context(group)
}

///|
fn CanvasState::end_group(self : CanvasState) -> Unit {
  if self.groups.pop() is Some(group) {
    self.ctx = group_finish(group)
  }
}

///|
fn CanvasState::start_mask(
  self : CanvasState,
  kind : Int32,
  backdrop : Int32,
  transfer : Bytes,
) -> Unit raise {
  if self.groups.length() + self.masks.length() >= 64 {
    raise BadFormat("groups nested too deep")
  }
  let mask = mask_begin(
    self.ctx,
    self.current_group(),
    kind,
    backdrop,
    transfer,
  )
  self.masks.push(mask)
  self.ctx = mask_context(mask)
}

///|
fn CanvasState::end_mask(self : CanvasState) -> Unit {
  if self.masks.pop() is Some(mask) {
    self.ctx = mask_finish(mask, self.current_group())
  }
}

///|
extern "js" fn mask_discard(mask : CanvasMask) -> Unit =
  #|(m) => { m.canvas.width=m.canvas.height=0; }

///|
fn CanvasState::finish(self : CanvasState) -> Unit {
  while self.masks.length() > 0 {
    if self.masks.pop() is Some(mask) {
      mask_discard(mask)
    }
  }
  while self.groups.length() > 0 {
    self.end_group()
  }
}
