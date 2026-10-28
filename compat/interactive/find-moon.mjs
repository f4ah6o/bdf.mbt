await import('./moon.mjs');
window.bdfStatus='loading';
try {
  const api=await import('/_build/js/debug/build/browser/browser.js');
  const host=document.querySelector('#host');
  window.findAction=(query,step=1)=>api.bdf_find(host,query,step);
  window.clearFind=()=>api.bdf_clear_find(host);
  window.openFind=()=>api.bdf_open_find(host);
  window.openFind();
  host.querySelector('input').value='page';
  window.findAction('page',0);
  host.focus({preventScroll:true});
  window.bdfStatus='ready';
} catch(error) { window.bdfStatus='error';window.bdfError=String(error?.stack??error);console.error(error); }
