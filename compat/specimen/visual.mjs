import { glyph_program } from '/_build/js/debug/build/compat/specimen/specimen.js';

try {
  const unzip = async bytes => new Uint8Array(await new Response(new Blob([bytes]).stream().pipeThrough(new DecompressionStream('gzip'))).arrayBuffer());
  const base64 = value => Uint8Array.from(atob(value), character => character.charCodeAt(0));
  const fixture = JSON.parse(new TextDecoder().decode(await unzip(await (await fetch('./upstream.json.gz')).arrayBuffer())));
  const samples = fixture.filter(sample => sample.visual);
  for (const [index, sample] of samples.entries()) {
    const program = document.body.dataset.converter === 'moon'
      ? glyph_program(await unzip(base64(sample.input)), sample.index)
      : await unzip(base64(sample.visual));
    const face = new FontFace('specimen-' + index, program);
    await face.load(); document.fonts.add(face);
    const canvas = document.createElement('canvas');
    canvas.width = 560; canvas.height = 145; document.querySelector('#host').append(canvas);
    const ctx = canvas.getContext('2d');
    ctx.fillStyle = '#222'; ctx.font = '12px sans-serif'; ctx.fillText(sample.name, 8, 14);
    ctx.font = '32px "specimen-' + index + '"'; ctx.textAlign = 'center';
    for (let glyph = 1; glyph <= 30; glyph++) {
      ctx.fillText(String.fromCodePoint(0xf0000 + glyph), 27 + ((glyph - 1) % 15) * 35, 53 + Math.floor((glyph - 1) / 15) * 47);
    }
  }
  window.bdfStatus = 'ready';
} catch (error) {
  window.bdfStatus = 'error'; window.bdfError = String(error?.stack ?? error); console.error(error);
}
