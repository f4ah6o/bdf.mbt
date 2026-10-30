import { BdfDocument, BufferSource } from '@bdfkit/core';
import { PageRenderer } from '@bdfkit/render';
import { xlsx_render_basic } from '/_build/js/debug/build/compat/xlsx/xlsx.js';
import { render_bdf_sheet_region_async } from '/_build/js/debug/build/browser/browser.js';

const bytes = value => Uint8Array.from(atob(value), character => character.charCodeAt(0));
function contains(haystack, needle) {
  outer: for (let i = 0; i <= haystack.length - needle.length; i++) {
    for (let j = 0; j < needle.length; j++) if (haystack[i + j] !== needle[j]) continue outer;
    return true;
  }
  return false;
}
try {
  const [fixtures, media] = await Promise.all(['picture-formats.json', 'picture-visual-media.json'].map(async file => {
    const response = await fetch('./' + file);
    if (!response.ok) throw new Error(`${file}: HTTP ${response.status}`);
    return response.json();
  }));
  for (const picture of media) {
    const sample = fixtures[picture.index];
    if (!sample) throw new Error(`${picture.label}: missing fixture ${picture.index}`);
    const imageBytes = bytes(picture.media);
    const image = new Image();
    const url = URL.createObjectURL(new Blob([imageBytes], { type: picture.mime }));
    try {
      image.src = url;
      await image.decode();
      if (image.naturalWidth !== picture.width || image.naturalHeight !== picture.height)
        throw new Error(`${picture.label}: decoded dimensions ${image.naturalWidth}x${image.naturalHeight}`);
    } finally { URL.revokeObjectURL(url); }
    const mode = document.body.dataset.mode;
    const data = mode === 'upstream' ? bytes(sample.bdf) :
      xlsx_render_basic(bytes(sample.input), sample.mode, sample.no_index);
    if (!data.length || !contains(data, imageBytes)) throw new Error(`${picture.label}: missing embedded image bytes`);
    const section = document.createElement('section');
    const title = document.createElement('h2'); title.textContent = picture.label;
    const surface = document.createElement('div'); surface.className = 'surface';
    section.append(title, surface); document.querySelector('#host').append(section);
    if (mode === 'moon') {
      await render_bdf_sheet_region_async(surface, data, 0, 0, 560, 115, 1);
    } else {
      const doc = await BdfDocument.open(new BufferSource(data));
      const canvas = document.createElement('canvas'); canvas.width = 560; canvas.height = 115;
      surface.append(canvas);
      await new PageRenderer(doc).renderSheet(canvas.getContext('2d'), doc.manifest.views[0],
        { x: 0, y: 0, w: 560, h: 115 }, { scale: 1 });
    }
  }
  window.bdfStatus = 'ready';
} catch (error) {
  window.bdfStatus = 'error'; window.bdfError = String(error?.stack ?? error); console.error(error);
}
