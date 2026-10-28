import { mount_bdf_interactive_async, bdf_selection_text } from '/_build/js/debug/build/browser/browser.js';
try {
  const bytes = new Uint8Array(await (await fetch('./fixture.bdf')).arrayBuffer());
  const host = document.querySelector('#host');
  await mount_bdf_interactive_async(host, bytes, 'single');
  window.readSelection = () => bdf_selection_text(host);
  window.bdfStatus='ready';
} catch (error) { window.bdfStatus='error';window.bdfError=String(error?.stack??error);console.error(error); }
