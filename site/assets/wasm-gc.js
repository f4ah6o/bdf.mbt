export function bytesToBase64(bytes) {
  let text = '';
  const chunk = 0x8000;
  for (let index = 0; index < bytes.length; index += chunk) {
    text += String.fromCharCode(...bytes.subarray(index, index + chunk));
  }
  return btoa(text);
}

export function base64ToBytes(value) {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
  return bytes;
}

export async function createWasm(url) {
  const response = await fetch(url);
  if (!response.ok) throw new Error('wasm-gc を読み込めませんでした: HTTP ' + response.status);
  const bytes = await response.arrayBuffer();
  const module = new WebAssembly.Module(bytes, {
    builtins: ['js-string'],
    importedStringConstants: '_',
  });
  const instance = await WebAssembly.instantiate(module, {
    console: { log() {} },
    spectest: { print_char() {} },
  });
  const call = (name, ...args) => {
    const exported = instance.exports[name];
    if (typeof exported !== 'function') throw new Error(name + ' が wasm-gc にありません');
    return exported(...args);
  };
  return {
    convertPdf(base64, password = '') {
      return JSON.parse(call('bdf_wasm_pdf', base64, password));
    },
    exportPdf(base64, tagged = false) {
      return JSON.parse(call('bdf_wasm_export_pdf', base64, tagged ? 1 : 0));
    },
    markdown(base64, images = 'zip') {
      return JSON.parse(call('bdf_wasm_markdown', base64, images));
    },
    searchText(base64) {
      return JSON.parse(call('bdf_wasm_search_text', base64));
    },
  };
}
