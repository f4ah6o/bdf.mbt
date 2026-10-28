try {
  const moon = location.pathname.endsWith('/moon.html');
  const client = moon
    ? (await import('/_build/js/debug/build/browser/browser.js')).bdf_create_render_worker('/_build/js/debug/build/render_worker/render_worker.js')
    : new (await import('/node_modules/@bdfkit/render/dist/client.js')).BdfWorkerClient(new Worker('/node_modules/@bdfkit/render/dist/worker.js', { type: 'module' }));
  const buffer = await (await fetch('/compat/visual/fixture.bdf')).arrayBuffer();
  const manifest = await client.open({ kind: 'buffer', buffer });
  const bitmap = await client.page(manifest.views[0].id, 0, 1);
  const canvas = document.createElement('canvas');
  canvas.width = bitmap.width; canvas.height = bitmap.height;
  canvas.getContext('2d').drawImage(bitmap, 0, 0); bitmap.close();
  document.querySelector('#host').append(canvas);
  client.terminate();
  window.bdfStatus = 'ready';
} catch (error) { window.bdfError = String(error); window.bdfStatus = 'error'; }
