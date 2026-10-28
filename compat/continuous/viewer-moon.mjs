import {mount_bdf_async} from '/_build/js/debug/build/browser/browser.js';
try{const bytes=new Uint8Array(await(await fetch('./scroll.bdf')).arrayBuffer());await mount_bdf_async(document.querySelector('#host'),bytes,'spread');window.bdfStatus='ready'}catch(error){window.bdfStatus='error';window.bdfError=String(error?.stack??error);console.error(error)}
