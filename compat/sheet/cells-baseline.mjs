import {BdfDocument,BufferSource,extractContent} from '@bdfkit/core';
import {PageRenderer,buildTextLayer,installCopyHandler,selectionCells,tableCells,cellClipboard,concat,TEXT_LAYER_CSS} from '@bdfkit/render';
try{
  const host=document.querySelector('#host'),bytes=new Uint8Array(await(await fetch('./cells.bdf')).arrayBuffer());
  const doc=await BdfDocument.open(new BufferSource(bytes)),view=doc.manifest.views[0],renderer=new PageRenderer(doc),parts=[];
  const tiles=Object.entries(view.tiles).map(([key,hash])=>{const [x,y]=key.split(',').map(Number);return{x,y,hash}}).sort((a,b)=>a.y-b.y||a.x-b.x);
  for(const tile of tiles){const object=await doc.ensure(tile.hash),c=extractContent(object,h=>doc.objectSync(h));parts.push({...c,runs:c.runs.filter(r=>r.x>=0&&r.x<view.tile&&r.y>=0&&r.y<view.tile).map(r=>({...r,x:r.x+tile.x*view.tile,y:r.y+tile.y*view.tile}))})}
  const all=concat(parts),visible=concat(parts.filter((_,i)=>tiles[i].x<2&&tiles[i].y<2));
  const style=document.createElement('style');style.textContent=TEXT_LAYER_CSS;document.head.append(style);
  const spacer=document.createElement('div');spacer.style.cssText='position:relative;width:648px;height:504px';const canvas=document.createElement('canvas');canvas.width=400;canvas.height=300;canvas.style.cssText='position:sticky;left:0;top:0;display:block';canvas.setAttribute('aria-label','BDF sheet');spacer.append(canvas);host.append(spacer);
  await renderer.renderSheet(canvas.getContext('2d'),view,{x:0,y:0,w:400,h:300},{scale:1});
  const layer=buildTextLayer(visible,1,{sheet:{rows:15,cols:10,headerRows:1,headerCols:1}});Object.assign(layer.style,{left:'0px',top:'0px',width:'648px',height:'504px'});spacer.append(layer);installCopyHandler(host);
  const first=[...layer.querySelectorAll('span')].find(s=>s.textContent==='Header'),last=[...layer.querySelectorAll('span')].find(s=>s.textContent==='End');
  const range=document.createRange();range.setStart(first.firstChild,0);range.setEnd(last.firstChild,last.textContent.length);getSelection().removeAllRanges();getSelection().addRange(range);document.dispatchEvent(new Event('selectionchange'));
  window.referenceCells=tableCells(all);window.referenceFor=range=>cellClipboard(window.referenceCells,range,{skipRow:r=>r===2,skipCol:c=>c===2});window.referenceClipboard=window.referenceFor({row0:0,col0:0,row1:4,col1:4});window.layerCells=selectionCells(getSelection(),host);
  window.bdfStatus='ready';
}catch(error){window.bdfStatus='error';window.bdfError=String(error?.stack??error);console.error(error)}
