import {BdfDocument,BufferSource} from '@bdfkit/core';
import {pianoRoll} from '/node_modules/@bdfkit/viewer/dist/music.js';
try{const bytes=new Uint8Array(await(await fetch('./fixtures/ode-mml.bdf')).arrayBuffer()),doc=await BdfDocument.open(new BufferSource(bytes)),view=doc.manifest.views[0],stage=document.querySelector('#host');await pianoRoll({stage,renderer:{play:()=>doc.play(view)},view,zoom:1,isCurrent:()=>true});stage.scrollTop=700;window.bdfStatus='ready'}catch(error){window.bdfStatus='error';window.bdfError=String(error);console.error(error)}
