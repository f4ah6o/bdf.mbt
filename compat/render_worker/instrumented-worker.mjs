const decode = self.createImageBitmap;
self.addEventListener('message', event => {
  if (event.data?.type !== 'test-stats') return;
  event.stopImmediatePropagation();
  self.postMessage({type:'test-stats', fonts:self.fonts?.size ?? null});
});
self.createImageBitmap = async (...args) => {
  self.postMessage({type:'test-image-decode'});
  await new Promise(resolve => setTimeout(resolve, 30));
  return decode(...args);
};
await import(new URL(import.meta.url).searchParams.get('worker'));
self.postMessage({type:'test-worker-ready'});
