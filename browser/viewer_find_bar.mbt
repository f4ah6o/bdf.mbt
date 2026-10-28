///|
extern "js" fn viewer_find_bar(dom : ViewerDom, drop : () -> Unit) -> Unit =
  #|(dom,drop) => {
  #| const setting=dom.options.find??(dom.mode==='lightbox'?'page':'focus');if(!setting)return;
  #| const labels={find:'Find in document',previous:'Previous match',next:'Next match',close:'Close',none:'No matches',count:(i,n,more)=>`${i} / ${n}${more?'+':''}`,...dom.options.findLabels};
  #| const bar=document.createElement('div'),input=document.createElement('input'),status=document.createElement('span');
  #| bar.style.cssText='position:absolute;top:8px;right:24px;z-index:10;display:none;align-items:center;gap:4px;max-width:calc(100% - 48px);box-sizing:border-box;padding:4px 6px;border:1px solid #b8b8b8;border-radius:6px;background:#fff;color:#222;box-shadow:0 2px 10px rgba(0,0,0,.25);font:13px/1.4 system-ui,sans-serif;color-scheme:light;text-align:left;direction:ltr';bar.setAttribute('role','search');
  #| input.type='search';input.placeholder=labels.find;input.setAttribute('aria-label',labels.find);input.autocomplete='off';input.spellcheck=false;input.style.cssText='flex:1 1 12em;width:12em;min-width:4em;box-sizing:border-box;margin:0;padding:3px 6px;border:1px solid #b8b8b8;border-radius:4px;background:#fff;color:#222;font:inherit';
  #| status.style.cssText='flex:none;min-width:4.5em;text-align:center;color:#555;white-space:nowrap;font-variant-numeric:tabular-nums';status.setAttribute('role','status');let timer;
  #| const fail=error=>{if(dom.api.dispatchEvent(new CustomEvent('error',{detail:error,cancelable:true})))console.error('bdf viewer:',error)};
  #| const run=(query,step)=>void dom.api.find(query,step).catch(fail),step=n=>{clearTimeout(timer);run(input.value,n)};
  #| const hide=()=>{clearTimeout(timer);bar.style.display='none';status.textContent=''};
  #| const close=()=>{if(bar.style.display==='none')return;hide();drop();dom.stage.focus({preventScroll:true})};
  #| const button=(text,label,click)=>{const b=document.createElement('button');b.type='button';b.textContent=text;b.title=label;b.setAttribute('aria-label',label);b.style.cssText='flex:none;width:26px;height:26px;margin:0;padding:0;border:0;border-radius:4px;background:transparent;color:#333;font:inherit;line-height:1;cursor:pointer';b.onpointerenter=()=>{b.style.background='#e8e8e8'};b.onpointerleave=()=>{b.style.background='transparent'};b.onclick=click;return b};
  #| bar.append(input,status,button('▲',labels.previous,()=>step(-1)),button('▼',labels.next,()=>step(1)),button('✕',labels.close,close));dom.box.append(bar);
  #| const typed=()=>{clearTimeout(timer);if(!input.value)run('',0);else timer=setTimeout(()=>run(input.value,0),150)};input.addEventListener('input',e=>{if(!e.isComposing)typed()});input.addEventListener('compositionend',typed);
  #| bar.addEventListener('keydown',e=>{if(e.isComposing||e.keyCode===229)return;if(e.key==='Escape'){e.preventDefault();e.stopPropagation();close()}else if(e.key==='Enter'&&e.target===input){e.preventDefault();step(e.shiftKey?-1:1)}});
  #| dom.findOpen=()=>{bar.style.display='flex';input.focus({preventScroll:true});input.select()};dom.findReset=()=>{hide();input.value=''};dom.findQuery=()=>input.value;
  #| dom.findReport=(state,hit,view)=>{if(!state||!state.query.trim()){status.textContent='';return}if(!state.total){status.textContent=labels.none;return}status.textContent=labels.count(state.index+1,state.total,!!state.more);if(hit){const d=document.createElement('span');d.style.cssText='position:absolute;width:1px;height:1px;overflow:hidden;clip-path:inset(50%);white-space:nowrap';const prefix=view.kind==='sheet'||view.kind==='scroll'?'':`page ${hit.segments[0].a+1}: `;d.textContent=' '+prefix+hit.context.replace(/ ⏎ /g,' ');status.append(d)}};
  #| const onkey=e=>{if(e.defaultPrevented||e.isComposing||e.altKey||!dom.view||dom.searchable===false||(dom.mode==='lightbox'&&dom.surface.style.display==='none'))return;const nav=navigator,apple=/mac|iphone|ipad|ipod/i.test(nav.userAgentData?.platform||nav.platform||nav.userAgent||'');let key='';if(e.key==='F3'&&!e.metaKey&&!e.ctrlKey)key=e.shiftKey?'previous':'next';else if(apple?e.metaKey&&!e.ctrlKey:e.ctrlKey&&!e.metaKey){const letter=/^[a-z]$/i.test(e.key)?e.key.toLowerCase():/^Key[A-Z]$/.test(e.code)&&!/^[\x20-\x7e]$/.test(e.key)?e.code[3].toLowerCase():'';if(letter==='f'&&!e.shiftKey)key='open';else if(letter==='g')key=e.shiftKey?'previous':'next'}if(key==='open'){if(bar.style.display!=='none'&&input.getRootNode().activeElement===input)return;e.preventDefault();dom.api.openFind()}else if(key&&bar.style.display!=='none'&&input.value){e.preventDefault();step(key==='next'?1:-1)}};
  #| const keys=setting==='page'?document:dom.surface;keys.addEventListener('keydown',onkey);dom.findDispose=()=>{clearTimeout(timer);keys.removeEventListener('keydown',onkey)};
  #|}

///|
extern "js" fn viewer_bar_open(dom : ViewerDom) -> Unit =
  #|(dom) => dom.findOpen?.()

///|
extern "js" fn viewer_bar_reset(dom : ViewerDom) -> Unit =
  #|(dom) => dom.findReset?.()

///|
extern "js" fn viewer_bar_query(dom : ViewerDom) -> String =
  #|(dom) => dom.findQuery?.()??''

///|
extern "js" fn viewer_dom_searchable(dom : ViewerDom, value : Bool) -> Unit =
  #|(dom,value) => {dom.searchable=value}
